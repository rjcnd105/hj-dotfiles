package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestFormatNotification_Fired(t *testing.T) {
	n := Notification{
		Kind: "fired",
		Key:  "recall@5|::bank",
		Alert: Alert{
			Metric: "recall@5", Bank: "::bank",
			Level: LevelCritical, Actual: 0.7, Threshold: 0.9,
		},
	}
	out := FormatNotification(n, "homelab")
	for _, want := range []string{"🔥", "recall@5", "::bank", "critical", "0.7", "0.9", "[homelab]"} {
		if !strings.Contains(out, want) {
			t.Fatalf("fired output missing %q:\n%s", want, out)
		}
	}
}

func TestFormatNotification_Recovered(t *testing.T) {
	n := Notification{
		Kind:               "recovered",
		Key:                "p90_latency_ms|::bank",
		RecoveredLevel:     LevelCritical,
		RecoveredLastValue: 12000,
	}
	out := FormatNotification(n, "")
	for _, want := range []string{"✅", "p90_latency_ms", "::bank", "critical", "12000"} {
		if !strings.Contains(out, want) {
			t.Fatalf("recovered output missing %q:\n%s", want, out)
		}
	}
	if strings.Contains(out, "[]") {
		t.Fatalf("empty host label should not produce brackets: %s", out)
	}
}

func TestTelegram_SendsCorrectPayload(t *testing.T) {
	var gotPath string
	var gotBody sendMessageRequest
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path
		body, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(body, &gotBody)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"ok":true}`))
	}))
	defer server.Close()

	n := TelegramNotifier{
		BotToken: "TEST_TOKEN",
		ChatID:   "12345",
		BaseURL:  server.URL,
		HTTP:     &http.Client{Timeout: 2 * time.Second},
		Host:     "homelab",
	}
	err := n.Send(Notification{
		Kind: "fired",
		Key:  "recall@5|::bank",
		Alert: Alert{
			Metric: "recall@5", Bank: "::bank",
			Level: LevelCritical, Actual: 0.5, Threshold: 0.9,
		},
	})
	if err != nil {
		t.Fatalf("send: %v", err)
	}
	if gotPath != "/botTEST_TOKEN/sendMessage" {
		t.Fatalf("path: %s", gotPath)
	}
	if gotBody.ChatID != "12345" {
		t.Fatalf("chat_id: %q", gotBody.ChatID)
	}
	if !strings.Contains(gotBody.Text, "recall@5") {
		t.Fatalf("text missing metric: %s", gotBody.Text)
	}
}

func TestTelegram_PropagatesServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "bad request", http.StatusBadRequest)
	}))
	defer server.Close()

	n := TelegramNotifier{
		BotToken: "x", ChatID: "y", BaseURL: server.URL,
		HTTP: &http.Client{Timeout: 2 * time.Second},
	}
	err := n.Send(Notification{Kind: "fired", Key: "m|b", Alert: Alert{Metric: "m", Bank: "b"}})
	if err == nil || !strings.Contains(err.Error(), "400") {
		t.Fatalf("want 400 err, got %v", err)
	}
}
