package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"sort"
	"time"
)

// Client talks to hindsight's memories/recall endpoint.
type Client struct {
	BaseURL string
	APIKey  string
	HTTP    *http.Client
}

func NewClient(baseURL, apiKey string) *Client {
	return &Client{
		BaseURL: baseURL,
		APIKey:  apiKey,
		// 12s per request: absolute upper bound. The 9s threshold is the
		// recall-path budget and is enforced downstream, not at the client.
		HTTP: &http.Client{Timeout: 12 * time.Second},
	}
}

type recallRequest struct {
	Query  string `json:"query"`
	Budget string `json:"budget"`
}

type recallResult struct {
	ID   string `json:"id"`
	Type string `json:"type"`
}

type recallResponse struct {
	Results []recallResult `json:"results"`
}

// Recall runs a single recall query. Returns the ordered list of result ids
// and the wall-clock latency.
func (c *Client) Recall(ctx context.Context, bank, query string) ([]string, time.Duration, error) {
	endpoint := fmt.Sprintf("%s/v1/default/banks/%s/memories/recall",
		c.BaseURL, url.PathEscape(bank))

	body, err := json.Marshal(recallRequest{Query: query, Budget: "mid"})
	if err != nil {
		return nil, 0, fmt.Errorf("marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", endpoint, bytes.NewReader(body))
	if err != nil {
		return nil, 0, fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+c.APIKey)
	req.Header.Set("Content-Type", "application/json")

	start := time.Now()
	resp, err := c.HTTP.Do(req)
	latency := time.Since(start)
	if err != nil {
		return nil, latency, fmt.Errorf("recall POST: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		snippet, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return nil, latency, fmt.Errorf("recall POST status %d: %s",
			resp.StatusCode, string(snippet))
	}

	var parsed recallResponse
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return nil, latency, fmt.Errorf("decode response: %w", err)
	}

	ids := make([]string, len(parsed.Results))
	for i, r := range parsed.Results {
		ids[i] = r.ID
	}
	return ids, latency, nil
}

// ScoreResult is per-fixture scoring.
type ScoreResult struct {
	FixtureID  string
	TopIDs     []string // what the server returned (truncated to top-K in caller)
	Hit        bool     // any expected id intersected with top-5?
	LatencyMs  int
	Error      string // network/server error for this fixture only
}

// ScoreFixtures runs every fixture's query through the client, collects per-
// fixture hit decisions, and rolls them up into Metrics. topK controls how
// many results count as "top" for the hit decision (default 5).
func ScoreFixtures(ctx context.Context, c *Client, set *FixtureSet, topK int) (Metrics, []ScoreResult) {
	if topK <= 0 {
		topK = 5
	}

	expectedByFixture := make([]map[string]struct{}, len(set.Fixtures))
	for i, fx := range set.Fixtures {
		m := make(map[string]struct{}, len(fx.ExpectedMemoryIDs))
		for _, id := range fx.ExpectedMemoryIDs {
			m[id] = struct{}{}
		}
		expectedByFixture[i] = m
	}

	seenTop := make(map[string]struct{})
	results := make([]ScoreResult, len(set.Fixtures))
	latencies := make([]int, 0, len(set.Fixtures))
	hits := 0
	unreachable := false

	for i, fx := range set.Fixtures {
		ids, latency, err := c.Recall(ctx, set.Bank, fx.Query)
		results[i] = ScoreResult{FixtureID: fx.ID, LatencyMs: int(latency.Milliseconds())}
		if err != nil {
			results[i].Error = err.Error()
			unreachable = true
			continue
		}

		top := ids
		if len(top) > topK {
			top = top[:topK]
		}
		results[i].TopIDs = top

		// "liveness" records a wider window (up to 10) to forgive small
		// ranking wobble when deciding whether a fixture's expected ids are
		// still alive in the corpus at all.
		wider := ids
		if len(wider) > 10 {
			wider = wider[:10]
		}
		for _, id := range wider {
			seenTop[id] = struct{}{}
		}

		for _, id := range top {
			if _, want := expectedByFixture[i][id]; want {
				results[i].Hit = true
				break
			}
		}
		if results[i].Hit {
			hits++
		}
		latencies = append(latencies, results[i].LatencyMs)
	}

	// Dead id = expected id that appeared in nobody's wider top-10.
	deadSet := make(map[string]struct{})
	for _, fx := range set.Fixtures {
		for _, id := range fx.ExpectedMemoryIDs {
			if _, alive := seenTop[id]; !alive {
				deadSet[id] = struct{}{}
			}
		}
	}
	dead := make([]string, 0, len(deadSet))
	for id := range deadSet {
		dead = append(dead, id)
	}
	sort.Strings(dead)

	metrics := Metrics{
		Bank:         set.Bank,
		P90LatencyMs: percentile(latencies, 90),
		DeadIDs:      dead,
		Unreachable:  unreachable,
	}
	if !unreachable && len(set.Fixtures) > 0 {
		metrics.RecallAt5 = float64(hits) / float64(len(set.Fixtures))
	}
	return metrics, results
}

func percentile(xs []int, p int) int {
	if len(xs) == 0 {
		return 0
	}
	sorted := append([]int(nil), xs...)
	sort.Ints(sorted)
	// Nearest-rank method: rank N = ceil(p/100 * n); 0-based index = N - 1.
	// 10 samples, p=90 → N=9 → index=8 → 9th smallest.
	rank := (p*len(sorted) + 99) / 100
	idx := rank - 1
	if idx >= len(sorted) {
		idx = len(sorted) - 1
	}
	if idx < 0 {
		idx = 0
	}
	return sorted[idx]
}

// HistoryRecord is one entry appended to history.jsonl per run.
// Shape matches origin brainstorm D6 (banks-keyed, fixture_metrics only).
type HistoryRecord struct {
	RunID           string                   `json:"run_id"`
	Mode            string                   `json:"mode"`
	FixtureVersion  string                   `json:"fixture_version"`
	HindsightImage  string                   `json:"hindsight_image,omitempty"`
	Banks           map[string]BankResults   `json:"banks"`
	Alerts          []Alert                  `json:"alerts,omitempty"`
}

type BankResults struct {
	FixtureMetrics    FixtureMetricsDump    `json:"fixture_metrics"`
	FixtureLiveness   FixtureLivenessDump   `json:"fixture_liveness"`
	Error             string                `json:"error,omitempty"`
}

type FixtureMetricsDump struct {
	RecallAt5    float64 `json:"recall@5"`
	P90LatencyMs int     `json:"p90_latency_ms"`
}

type FixtureLivenessDump struct {
	Checked int      `json:"checked"`
	Alive   int      `json:"alive"`
	DeadIDs []string `json:"dead_ids"`
}

// AppendHistory writes one JSON line to path, creating the file if needed.
// Rotation is out of scope (JSONL, linear growth acceptable at MVP volume).
func AppendHistory(path string, rec HistoryRecord) error {
	data, err := json.Marshal(rec)
	if err != nil {
		return fmt.Errorf("marshal record: %w", err)
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		return fmt.Errorf("open history: %w", err)
	}
	defer f.Close()
	if _, err := f.Write(append(data, '\n')); err != nil {
		return fmt.Errorf("write history: %w", err)
	}
	return nil
}

// BuildHistoryRecord assembles the record for one run. It deliberately
// excludes query strings from every field to honor the security requirement
// that bank memory content does not land in the JSONL log.
func BuildHistoryRecord(runID, mode, fixtureVersion, hindsightImage string,
	metrics Metrics, alerts []Alert, totalFixtures int,
) HistoryRecord {
	liveness := FixtureLivenessDump{
		Checked: totalFixtures,
		Alive:   totalFixtures - len(metrics.DeadIDs),
		DeadIDs: metrics.DeadIDs,
	}
	if liveness.DeadIDs == nil {
		liveness.DeadIDs = []string{}
	}
	bank := BankResults{
		FixtureMetrics: FixtureMetricsDump{
			RecallAt5:    metrics.RecallAt5,
			P90LatencyMs: metrics.P90LatencyMs,
		},
		FixtureLiveness: liveness,
	}
	if metrics.Unreachable {
		bank.Error = "hindsight recall unreachable"
	}
	return HistoryRecord{
		RunID:          runID,
		Mode:           mode,
		FixtureVersion: fixtureVersion,
		HindsightImage: hindsightImage,
		Banks:          map[string]BankResults{metrics.Bank: bank},
		Alerts:         alerts,
	}
}
