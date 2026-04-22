package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

// TelegramNotifier posts each notification to the Telegram Bot API. Delivery
// failure is surfaced to the caller (main.go) which logs but does not abort
// the eval — notifications are best-effort.
type TelegramNotifier struct {
	BotToken string
	ChatID   string
	BaseURL  string // overridable in tests
	HTTP     *http.Client
	Host     string // hostname label included in every message
}

func NewTelegramNotifier(botToken, chatID string) *TelegramNotifier {
	host, _ := os.Hostname()
	return &TelegramNotifier{
		BotToken: botToken,
		ChatID:   chatID,
		BaseURL:  "https://api.telegram.org",
		HTTP:     &http.Client{Timeout: 8 * time.Second},
		Host:     host,
	}
}

type sendMessageRequest struct {
	ChatID    string `json:"chat_id"`
	Text      string `json:"text"`
	ParseMode string `json:"parse_mode,omitempty"`
}

func (t *TelegramNotifier) Send(n Notification) error {
	text := FormatNotification(n, t.Host)
	payload, err := json.Marshal(sendMessageRequest{
		ChatID: t.ChatID,
		Text:   text,
	})
	if err != nil {
		return fmt.Errorf("marshal telegram payload: %w", err)
	}

	endpoint := fmt.Sprintf("%s/bot%s/sendMessage", t.BaseURL, t.BotToken)
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewReader(payload))
	if err != nil {
		return fmt.Errorf("build telegram request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := t.HTTP.Do(req)
	if err != nil {
		return fmt.Errorf("telegram POST: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return fmt.Errorf("telegram status %d: %s", resp.StatusCode, string(snippet))
	}
	return nil
}

// FormatNotification renders a Notification as plain text. Kept in its own
// function so tests can exercise formatting without the network.
func FormatNotification(n Notification, host string) string {
	hostLabel := ""
	if host != "" {
		hostLabel = " [" + host + "]"
	}
	var b strings.Builder
	switch n.Kind {
	case "fired":
		fmt.Fprintf(&b, "🔥 recall-eval alert%s\n", hostLabel)
		fmt.Fprintf(&b, "metric: %s\n", n.Alert.Metric)
		fmt.Fprintf(&b, "bank: %s\n", n.Alert.Bank)
		fmt.Fprintf(&b, "level: %s\n", n.Alert.Level)
		fmt.Fprintf(&b, "actual: %g\n", n.Alert.Actual)
		fmt.Fprintf(&b, "threshold: %g", n.Alert.Threshold)
	case "upgraded":
		fmt.Fprintf(&b, "⬆️ recall-eval upgraded%s\n", hostLabel)
		fmt.Fprintf(&b, "metric: %s\n", n.Alert.Metric)
		fmt.Fprintf(&b, "bank: %s\n", n.Alert.Bank)
		fmt.Fprintf(&b, "level: %s\n", n.Alert.Level)
		fmt.Fprintf(&b, "actual: %g\n", n.Alert.Actual)
		fmt.Fprintf(&b, "threshold: %g", n.Alert.Threshold)
	case "recovered":
		parts := strings.SplitN(n.Key, "|", 2)
		metric, bank := n.Key, ""
		if len(parts) == 2 {
			metric, bank = parts[0], parts[1]
		}
		fmt.Fprintf(&b, "✅ recall-eval recovered%s\n", hostLabel)
		fmt.Fprintf(&b, "metric: %s\n", metric)
		fmt.Fprintf(&b, "bank: %s\n", bank)
		fmt.Fprintf(&b, "was: %s\n", n.RecoveredLevel)
		fmt.Fprintf(&b, "last_value: %g", n.RecoveredLastValue)
	default:
		fmt.Fprintf(&b, "recall-eval notification%s: %s %s", hostLabel, n.Kind, n.Key)
	}
	return b.String()
}
