package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"
)

func main() {
	mode := flag.String("mode", "gate", "run mode: gate | on-switch | ack-all")
	fixturesPath := flag.String("fixtures", "/run/credentials/recall-eval-gate.service/fixtures.yaml",
		"path to fixtures yaml (decrypted)")
	stateDir := flag.String("state-dir", "/var/lib/recall-eval", "state directory")
	hindsightURL := flag.String("hindsight-url", "http://127.0.0.1:8888",
		"hindsight API base URL")
	flag.Parse()

	if err := run(*mode, *fixturesPath, *stateDir, *hindsightURL); err != nil {
		log.SetFlags(0)
		log.Printf("recall-eval: %v", err)
		os.Exit(2)
	}
}

func run(mode, fixturesPath, stateDir, hindsightURL string) error {
	if err := os.MkdirAll(stateDir, 0700); err != nil {
		return fmt.Errorf("state dir: %w", err)
	}
	statePath := filepath.Join(stateDir, "alert-state.json")
	historyPath := filepath.Join(stateDir, "history.jsonl")

	if mode == "ack-all" {
		state, err := LoadAlertState(statePath)
		if err != nil {
			return err
		}
		state.AckAll(time.Now().UTC())
		if err := SaveAlertState(statePath, state); err != nil {
			return err
		}
		fmt.Printf("acknowledged %d alert entries\n", len(state.Entries))
		return nil
	}

	if mode != "gate" && mode != "on-switch" {
		return fmt.Errorf("unknown mode %q", mode)
	}

	apiKey := os.Getenv("HINDSIGHT_API_TENANT_API_KEY")
	if apiKey == "" {
		return fmt.Errorf("HINDSIGHT_API_TENANT_API_KEY not set")
	}

	set, err := LoadFixtures(fixturesPath)
	if err != nil {
		return err
	}

	runID := time.Now().UTC().Format(time.RFC3339)
	hindsightImage := os.Getenv("HINDSIGHT_IMAGE_TAG") // optional; empty = omitted

	client := NewClient(hindsightURL, apiKey)
	ctx, cancel := context.WithTimeout(context.Background(),
		time.Duration(len(set.Fixtures)+1)*13*time.Second)
	defer cancel()

	metrics, perFixture := ScoreFixtures(ctx, client, set, 5)
	alerts := Evaluate(metrics)

	prior, err := LoadAlertState(statePath)
	if err != nil {
		return err
	}
	next, notifs := Transition(prior, alerts, time.Now().UTC())
	if err := SaveAlertState(statePath, next); err != nil {
		return err
	}

	var notifier Notifier = NoopNotifier{}
	tok := os.Getenv("TELEGRAM_BOT_TOKEN")
	chat := os.Getenv("TELEGRAM_CHAT_ID")
	if tok != "" && chat != "" {
		notifier = NewTelegramNotifier(tok, chat)
	} else {
		log.Printf("notifier: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID missing; using noop")
	}
	for _, n := range notifs {
		if err := notifier.Send(n); err != nil {
			log.Printf("notifier: %v", err)
		}
	}

	record := BuildHistoryRecord(runID, mode, set.VersionHash, hindsightImage,
		metrics, alerts, len(set.Fixtures))
	if err := AppendHistory(historyPath, record); err != nil {
		return err
	}

	fmt.Printf("mode=%s fixtures=%d hits=%d/%d recall@5=%.2f p90_latency_ms=%d dead_ids=%d alerts=%d\n",
		mode, len(set.Fixtures),
		countHits(perFixture), len(set.Fixtures),
		metrics.RecallAt5, metrics.P90LatencyMs, len(metrics.DeadIDs), len(alerts))

	if metrics.Unreachable {
		fmt.Fprintln(os.Stderr, "recall-eval: hindsight unreachable; see alert for details")
	}

	// on-switch mode is alert-only: activation scripts must not block the
	// system switch even if recall@5 regresses. gate mode propagates.
	if mode == "on-switch" {
		return nil
	}
	for _, a := range alerts {
		if a.Level == LevelCritical {
			return fmt.Errorf("critical alert: metric=%s actual=%.3f threshold=%.3f",
				a.Metric, a.Actual, a.Threshold)
		}
	}
	return nil
}

func countHits(xs []ScoreResult) int {
	n := 0
	for _, x := range xs {
		if x.Hit {
			n++
		}
	}
	return n
}
