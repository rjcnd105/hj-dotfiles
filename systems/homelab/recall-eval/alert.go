package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

type AlertLevel string

const (
	LevelCritical AlertLevel = "critical"
	LevelWarning  AlertLevel = "warning"
)

type Alert struct {
	Metric    string     `json:"metric"`
	Bank      string     `json:"bank"`
	Level     AlertLevel `json:"level"`
	Actual    float64    `json:"actual"`
	Threshold float64    `json:"threshold"`
}

type Metrics struct {
	Bank         string
	RecallAt5    float64
	P90LatencyMs int
	DeadIDs      []string
	Unreachable  bool // hindsight network/server failure
}

const (
	RecallAt5Threshold    = 0.90
	P90LatencyMsThreshold = 9000
)

// Evaluate produces the alerts implied by the given metrics.
// Returned alerts are sorted deterministically (by metric name).
func Evaluate(m Metrics) []Alert {
	var alerts []Alert
	if m.Unreachable {
		alerts = append(alerts, Alert{
			Metric: "recall_unreachable", Bank: m.Bank, Level: LevelCritical,
			Actual: 0, Threshold: 0,
		})
		return alerts
	}
	if m.RecallAt5 < RecallAt5Threshold {
		alerts = append(alerts, Alert{
			Metric: "recall@5", Bank: m.Bank, Level: LevelCritical,
			Actual: m.RecallAt5, Threshold: RecallAt5Threshold,
		})
	}
	if m.P90LatencyMs > P90LatencyMsThreshold {
		alerts = append(alerts, Alert{
			Metric: "p90_latency_ms", Bank: m.Bank, Level: LevelCritical,
			Actual: float64(m.P90LatencyMs), Threshold: P90LatencyMsThreshold,
		})
	}
	if len(m.DeadIDs) > 0 {
		alerts = append(alerts, Alert{
			Metric: "fixture_liveness", Bank: m.Bank, Level: LevelWarning,
			Actual: float64(len(m.DeadIDs)), Threshold: 0,
		})
	}
	return alerts
}

// StateEntry tracks an alert through time. Acknowledgement only suppresses
// the Claude hook surface; Telegram still fires on transition.
type StateEntry struct {
	Level          AlertLevel `json:"level"`
	FirstFiredAt   time.Time  `json:"first_fired_at"`
	LastNotifiedAt time.Time  `json:"last_notified_at"`
	AcknowledgedAt *time.Time `json:"acknowledged_at,omitempty"`
	LastValue      float64    `json:"last_value"`
}

type AlertState struct {
	// Key is "<metric>|<bank>".
	Entries map[string]StateEntry `json:"entries"`
}

func NewAlertState() AlertState {
	return AlertState{Entries: map[string]StateEntry{}}
}

func stateKey(metric, bank string) string {
	return metric + "|" + bank
}

// Notification is emitted when Transition decides to tell the world about a
// state change. The orchestrator converts each notification into Telegram
// output (and records LastNotifiedAt on the surviving state entry).
type Notification struct {
	Kind  string // "fired" | "recovered" | "upgraded"
	Key   string // "<metric>|<bank>"
	Alert Alert  // zero for "recovered"
	// For "recovered", the level the alert had before recovery.
	RecoveredLevel    AlertLevel
	RecoveredLastValue float64
}

// Transition folds the current batch of alerts into the prior state,
// producing (a) the new state to persist and (b) the transitions worth
// notifying about.
//
// Rules (D10 of origin brainstorm):
//   - OK -> critical/warning: fire
//   - level unchanged for same (metric, bank): persist, no fire
//   - level changed (e.g. warning -> critical): upgrade notification
//   - present in prior but absent in current: recovered
//   - AcknowledgedAt is cleared whenever the alert recovers or upgrades, since
//     those are fresh signals that deserve re-review in the Claude hook.
func Transition(prior AlertState, alerts []Alert, now time.Time) (AlertState, []Notification) {
	next := NewAlertState()
	var notifs []Notification

	current := make(map[string]Alert, len(alerts))
	for _, a := range alerts {
		current[stateKey(a.Metric, a.Bank)] = a
	}

	for key, a := range current {
		prev, had := prior.Entries[key]
		switch {
		case !had:
			entry := StateEntry{
				Level:          a.Level,
				FirstFiredAt:   now,
				LastNotifiedAt: now,
				LastValue:      a.Actual,
			}
			next.Entries[key] = entry
			notifs = append(notifs, Notification{Kind: "fired", Key: key, Alert: a})
		case prev.Level != a.Level:
			entry := StateEntry{
				Level:          a.Level,
				FirstFiredAt:   now, // level change is a fresh incident
				LastNotifiedAt: now,
				LastValue:      a.Actual,
				// AcknowledgedAt intentionally cleared: escalation needs re-ack
			}
			next.Entries[key] = entry
			notifs = append(notifs, Notification{Kind: "upgraded", Key: key, Alert: a})
		default:
			entry := StateEntry{
				Level:          prev.Level,
				FirstFiredAt:   prev.FirstFiredAt,
				LastNotifiedAt: prev.LastNotifiedAt,
				AcknowledgedAt: prev.AcknowledgedAt,
				LastValue:      a.Actual,
			}
			next.Entries[key] = entry
		}
	}

	// Anything in prior but not current recovered.
	for key, prev := range prior.Entries {
		if _, stillActive := current[key]; stillActive {
			continue
		}
		notifs = append(notifs, Notification{
			Kind:               "recovered",
			Key:                key,
			RecoveredLevel:     prev.Level,
			RecoveredLastValue: prev.LastValue,
		})
	}

	return next, notifs
}

// AckAll marks every entry in the state as acknowledged at `now`.
// Used by `recall-eval --ack-all` which backs `just recall-eval-ack`.
func (s *AlertState) AckAll(now time.Time) {
	for k, e := range s.Entries {
		stamp := now
		e.AcknowledgedAt = &stamp
		s.Entries[k] = e
	}
}

// LoadAlertState reads the state file. Missing file is not an error.
func LoadAlertState(path string) (AlertState, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return NewAlertState(), nil
		}
		return AlertState{}, fmt.Errorf("read alert-state: %w", err)
	}
	var state AlertState
	if err := json.Unmarshal(data, &state); err != nil {
		return AlertState{}, fmt.Errorf("parse alert-state: %w", err)
	}
	if state.Entries == nil {
		state.Entries = map[string]StateEntry{}
	}
	return state, nil
}

// SaveAlertState writes atomically via tmp + rename. State directory must
// already exist (systemd's StateDirectory= provides it).
func SaveAlertState(path string, state AlertState) error {
	data, err := json.MarshalIndent(state, "", "  ")
	if err != nil {
		return fmt.Errorf("marshal alert-state: %w", err)
	}
	dir := filepath.Dir(path)
	tmp, err := os.CreateTemp(dir, ".alert-state-*.json")
	if err != nil {
		return fmt.Errorf("create tmp: %w", err)
	}
	tmpName := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(tmpName)
		return fmt.Errorf("write tmp: %w", err)
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("close tmp: %w", err)
	}
	if err := os.Chmod(tmpName, 0600); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("chmod tmp: %w", err)
	}
	if err := os.Rename(tmpName, path); err != nil {
		os.Remove(tmpName)
		return fmt.Errorf("rename: %w", err)
	}
	return nil
}

// Notifier abstracts Telegram delivery. Unit 2 ships the noop impl; Unit 4
// replaces it with a real HTTPS POST implementation.
type Notifier interface {
	Send(n Notification) error
}

type NoopNotifier struct{}

func (NoopNotifier) Send(Notification) error { return nil }
