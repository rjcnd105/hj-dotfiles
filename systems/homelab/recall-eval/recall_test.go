package main

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// fakeHindsight lets a test script per-query return whichever result ids it
// wants; mapping nil returns an empty results list.
func fakeHindsight(t *testing.T, mapping map[string][]string) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "want POST", http.StatusMethodNotAllowed)
			return
		}
		expectedPrefix := "/v1/default/banks/"
		if !strings.HasPrefix(r.URL.Path, expectedPrefix) ||
			!strings.HasSuffix(r.URL.Path, "/memories/recall") {
			http.Error(w, "path "+r.URL.Path, http.StatusNotFound)
			return
		}
		body, _ := io.ReadAll(r.Body)
		var req recallRequest
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, "bad json", http.StatusBadRequest)
			return
		}
		ids := mapping[req.Query]
		results := make([]recallResult, len(ids))
		for i, id := range ids {
			results[i] = recallResult{ID: id, Type: "world"}
		}
		json.NewEncoder(w).Encode(recallResponse{Results: results})
	}))
}

func newTestClient(t *testing.T, base string) *Client {
	t.Helper()
	c := NewClient(base, "test-key")
	c.HTTP = &http.Client{Timeout: 2 * time.Second}
	return c
}

func TestRecall_ParsesIDs(t *testing.T) {
	server := fakeHindsight(t, map[string][]string{
		"q1": {"id-1", "id-2", "id-3"},
	})
	defer server.Close()

	c := newTestClient(t, server.URL)
	ids, _, err := c.Recall(context.Background(), "::bank", "q1")
	if err != nil {
		t.Fatalf("recall: %v", err)
	}
	if len(ids) != 3 || ids[0] != "id-1" {
		t.Fatalf("ids: %v", ids)
	}
}

func TestRecall_ServerError(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "boom", http.StatusInternalServerError)
	}))
	defer server.Close()

	c := newTestClient(t, server.URL)
	_, _, err := c.Recall(context.Background(), "::bank", "q")
	if err == nil || !strings.Contains(err.Error(), "status 500") {
		t.Fatalf("want status 500 err, got %v", err)
	}
}

func TestRecall_Unreachable(t *testing.T) {
	// Create a server, then close it so connect is refused.
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	url := server.URL
	server.Close()

	c := newTestClient(t, url)
	_, _, err := c.Recall(context.Background(), "::bank", "q")
	if err == nil {
		t.Fatal("expected network error")
	}
}

func TestScoreFixtures_AllHit(t *testing.T) {
	server := fakeHindsight(t, map[string][]string{
		"q1": {"a", "b", "c"},
		"q2": {"x", "y"},
	})
	defer server.Close()

	set := &FixtureSet{
		Version: 1, Bank: "::bank",
		Fixtures: []Fixture{
			{ID: "fx-1", Query: "q1", ExpectedMemoryIDs: []string{"b"}},
			{ID: "fx-2", Query: "q2", ExpectedMemoryIDs: []string{"y"}},
		},
	}
	metrics, per := ScoreFixtures(context.Background(), newTestClient(t, server.URL), set, 5)
	if metrics.RecallAt5 != 1.0 {
		t.Fatalf("want 1.0, got %v", metrics.RecallAt5)
	}
	if metrics.Unreachable {
		t.Fatal("unreachable should be false when every call succeeds")
	}
	if len(metrics.DeadIDs) != 0 {
		t.Fatalf("no dead ids expected, got %v", metrics.DeadIDs)
	}
	for _, r := range per {
		if !r.Hit {
			t.Fatalf("fixture %s should have hit", r.FixtureID)
		}
	}
}

func TestScoreFixtures_PartialAndDead(t *testing.T) {
	server := fakeHindsight(t, map[string][]string{
		"q1": {"a", "b", "c"},         // expected "b" → hit
		"q2": {"x", "y"},              // expected "unseen" → miss, dead
		"q3": {"m", "n", "o", "p", "q"}, // expected "a" → miss (but "a" is alive via q1)
	})
	defer server.Close()

	set := &FixtureSet{
		Version: 1, Bank: "::bank",
		Fixtures: []Fixture{
			{ID: "fx-1", Query: "q1", ExpectedMemoryIDs: []string{"b"}},
			{ID: "fx-2", Query: "q2", ExpectedMemoryIDs: []string{"unseen"}},
			{ID: "fx-3", Query: "q3", ExpectedMemoryIDs: []string{"a"}},
		},
	}
	metrics, _ := ScoreFixtures(context.Background(), newTestClient(t, server.URL), set, 5)

	if metrics.RecallAt5 != 1.0/3.0 {
		t.Fatalf("recall@5 want 1/3, got %v", metrics.RecallAt5)
	}
	if len(metrics.DeadIDs) != 1 || metrics.DeadIDs[0] != "unseen" {
		t.Fatalf("dead ids: %v", metrics.DeadIDs)
	}
}

func TestScoreFixtures_UnreachableShortCircuits(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Error(w, "boom", http.StatusInternalServerError)
	}))
	defer server.Close()

	set := &FixtureSet{
		Version: 1, Bank: "::bank",
		Fixtures: []Fixture{
			{ID: "fx-1", Query: "q1", ExpectedMemoryIDs: []string{"b"}},
		},
	}
	metrics, _ := ScoreFixtures(context.Background(), newTestClient(t, server.URL), set, 5)
	if !metrics.Unreachable {
		t.Fatal("expect Unreachable=true on server errors")
	}
	if metrics.RecallAt5 != 0 {
		t.Fatalf("recall@5 should be zero on unreachable, got %v", metrics.RecallAt5)
	}
}

func TestAppendHistory_RoundtripJSONL(t *testing.T) {
	path := filepath.Join(t.TempDir(), "history.jsonl")
	rec := BuildHistoryRecord("run-1", "gate", "hash-1", "img-1",
		Metrics{Bank: "::bank", RecallAt5: 0.9, P90LatencyMs: 5000, DeadIDs: []string{"x"}},
		nil, 10)
	if err := AppendHistory(path, rec); err != nil {
		t.Fatal(err)
	}
	if err := AppendHistory(path, rec); err != nil {
		t.Fatal(err)
	}
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.Count(string(content), "\n"); got != 2 {
		t.Fatalf("want 2 lines, got %d", got)
	}
	if strings.Contains(string(content), "query") {
		t.Fatalf("history must never contain query strings: %s", content)
	}
}

func TestPercentile_P90NearestRank(t *testing.T) {
	in := []int{100, 200, 300, 400, 500, 600, 700, 800, 900, 1000}
	got := percentile(in, 90)
	if got != 900 {
		t.Fatalf("p90 want 900, got %d", got)
	}
}
