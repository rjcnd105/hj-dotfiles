package main

import (
	"path/filepath"
	"testing"
	"time"
)

var testBank = "::nix-dots"

func TestEvaluate_Healthy(t *testing.T) {
	m := Metrics{Bank: testBank, RecallAt5: 1.0, P90LatencyMs: 5000}
	if got := Evaluate(m); len(got) != 0 {
		t.Fatalf("expect no alerts, got %+v", got)
	}
}

func TestEvaluate_RecallBoundary(t *testing.T) {
	// recall@5 == 0.90 is inclusive — no alert.
	m := Metrics{Bank: testBank, RecallAt5: 0.90, P90LatencyMs: 5000}
	if got := Evaluate(m); len(got) != 0 {
		t.Fatalf("boundary should be healthy, got %+v", got)
	}
}

func TestEvaluate_RecallBelow(t *testing.T) {
	m := Metrics{Bank: testBank, RecallAt5: 0.80, P90LatencyMs: 5000}
	alerts := Evaluate(m)
	if len(alerts) != 1 || alerts[0].Metric != "recall@5" ||
		alerts[0].Level != LevelCritical || alerts[0].Actual != 0.80 {
		t.Fatalf("recall@5 critical expected, got %+v", alerts)
	}
}

func TestEvaluate_LatencyAboveBudget(t *testing.T) {
	// 10s > 9s budget
	m := Metrics{Bank: testBank, RecallAt5: 1.0, P90LatencyMs: 10000}
	alerts := Evaluate(m)
	if len(alerts) != 1 || alerts[0].Metric != "p90_latency_ms" {
		t.Fatalf("p90 alert expected, got %+v", alerts)
	}
}

func TestEvaluate_DeadIDsWarning(t *testing.T) {
	m := Metrics{Bank: testBank, RecallAt5: 1.0, P90LatencyMs: 5000, DeadIDs: []string{"x"}}
	alerts := Evaluate(m)
	if len(alerts) != 1 || alerts[0].Level != LevelWarning ||
		alerts[0].Metric != "fixture_liveness" {
		t.Fatalf("liveness warning expected, got %+v", alerts)
	}
}

func TestEvaluate_UnreachableSwallowsOthers(t *testing.T) {
	m := Metrics{Bank: testBank, Unreachable: true, RecallAt5: 0.1, P90LatencyMs: 99999}
	alerts := Evaluate(m)
	if len(alerts) != 1 || alerts[0].Metric != "recall_unreachable" {
		t.Fatalf("unreachable should be the only alert, got %+v", alerts)
	}
}

func TestTransition_OKToCriticalFires(t *testing.T) {
	prior := NewAlertState()
	now := time.Unix(1000, 0)
	a := Alert{Metric: "recall@5", Bank: testBank, Level: LevelCritical, Actual: 0.8, Threshold: 0.9}

	next, notifs := Transition(prior, []Alert{a}, now)

	if len(notifs) != 1 || notifs[0].Kind != "fired" {
		t.Fatalf("want fired notification, got %+v", notifs)
	}
	if got, want := len(next.Entries), 1; got != want {
		t.Fatalf("entries: want %d, got %d", want, got)
	}
	entry := next.Entries["recall@5|"+testBank]
	if !entry.FirstFiredAt.Equal(now) || entry.LastValue != 0.8 {
		t.Fatalf("entry wrong: %+v", entry)
	}
}

func TestTransition_CriticalPersistsNoFire(t *testing.T) {
	old := time.Unix(100, 0)
	prior := AlertState{Entries: map[string]StateEntry{
		"recall@5|" + testBank: {
			Level: LevelCritical, FirstFiredAt: old, LastNotifiedAt: old, LastValue: 0.8,
		},
	}}
	a := Alert{Metric: "recall@5", Bank: testBank, Level: LevelCritical, Actual: 0.85, Threshold: 0.9}

	_, notifs := Transition(prior, []Alert{a}, time.Unix(200, 0))
	if len(notifs) != 0 {
		t.Fatalf("persistence should not notify, got %+v", notifs)
	}
}

func TestTransition_CrossMetricCriticalFires(t *testing.T) {
	old := time.Unix(100, 0)
	prior := AlertState{Entries: map[string]StateEntry{
		"recall@5|" + testBank: {Level: LevelCritical, FirstFiredAt: old, LastNotifiedAt: old, LastValue: 0.8},
	}}
	a1 := Alert{Metric: "recall@5", Bank: testBank, Level: LevelCritical, Actual: 0.85}
	a2 := Alert{Metric: "p90_latency_ms", Bank: testBank, Level: LevelCritical, Actual: 12000}

	_, notifs := Transition(prior, []Alert{a1, a2}, time.Unix(200, 0))
	if len(notifs) != 1 || notifs[0].Alert.Metric != "p90_latency_ms" || notifs[0].Kind != "fired" {
		t.Fatalf("only the new metric should fire, got %+v", notifs)
	}
}

func TestTransition_Recovered(t *testing.T) {
	old := time.Unix(100, 0)
	prior := AlertState{Entries: map[string]StateEntry{
		"recall@5|" + testBank: {Level: LevelCritical, FirstFiredAt: old, LastNotifiedAt: old, LastValue: 0.8},
	}}
	// Current run has no alerts — recall is back above threshold.
	next, notifs := Transition(prior, nil, time.Unix(200, 0))
	if len(notifs) != 1 || notifs[0].Kind != "recovered" ||
		notifs[0].RecoveredLevel != LevelCritical {
		t.Fatalf("want recovered, got %+v", notifs)
	}
	if len(next.Entries) != 0 {
		t.Fatalf("recovered key should be removed, got %+v", next.Entries)
	}
}

func TestTransition_Upgrade(t *testing.T) {
	old := time.Unix(100, 0)
	ack := time.Unix(150, 0)
	prior := AlertState{Entries: map[string]StateEntry{
		"fixture_liveness|" + testBank: {
			Level: LevelWarning, FirstFiredAt: old, LastNotifiedAt: old,
			AcknowledgedAt: &ack, LastValue: 1,
		},
	}}
	a := Alert{Metric: "fixture_liveness", Bank: testBank, Level: LevelCritical, Actual: 5}

	next, notifs := Transition(prior, []Alert{a}, time.Unix(200, 0))
	if len(notifs) != 1 || notifs[0].Kind != "upgraded" {
		t.Fatalf("want upgrade, got %+v", notifs)
	}
	entry := next.Entries["fixture_liveness|"+testBank]
	if entry.AcknowledgedAt != nil {
		t.Fatalf("upgrade must clear ack, got %+v", entry)
	}
}

func TestAlertState_SaveLoadRoundTrip(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "alert-state.json")

	now := time.Unix(1000, 0).UTC()
	state := NewAlertState()
	state.Entries["recall@5|bank"] = StateEntry{
		Level: LevelCritical, FirstFiredAt: now, LastNotifiedAt: now, LastValue: 0.8,
	}
	if err := SaveAlertState(path, state); err != nil {
		t.Fatalf("save: %v", err)
	}

	got, err := LoadAlertState(path)
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if got.Entries["recall@5|bank"].LastValue != 0.8 {
		t.Fatalf("round trip mismatch: %+v", got)
	}
}

func TestAlertState_LoadMissing(t *testing.T) {
	got, err := LoadAlertState(filepath.Join(t.TempDir(), "nope.json"))
	if err != nil {
		t.Fatalf("missing file should be OK, got %v", err)
	}
	if got.Entries == nil || len(got.Entries) != 0 {
		t.Fatalf("want empty state, got %+v", got)
	}
}

func TestAckAll_StampsEveryEntry(t *testing.T) {
	state := NewAlertState()
	state.Entries["a|b"] = StateEntry{Level: LevelCritical}
	state.Entries["c|d"] = StateEntry{Level: LevelWarning}

	now := time.Unix(2000, 0)
	state.AckAll(now)
	for k, e := range state.Entries {
		if e.AcknowledgedAt == nil || !e.AcknowledgedAt.Equal(now) {
			t.Fatalf("entry %s not ack'd: %+v", k, e)
		}
	}
}
