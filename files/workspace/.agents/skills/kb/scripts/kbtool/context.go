package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

const defaultContextLimit = 4
const defaultContextMinScore = 20

type contextReport struct {
	Vault      string             `json:"vault"`
	Query      string             `json:"query"`
	Mode       string             `json:"mode"`
	Limit      int                `json:"limit"`
	MinScore   int                `json:"min_score"`
	Candidates []contextCandidate `json:"candidates"`
}

type contextCandidate struct {
	Name    string   `json:"name"`
	Path    string   `json:"path"`
	Score   int      `json:"score"`
	Reasons []string `json:"reasons"`
	Snippet string   `json:"snippet,omitempty"`
	Links   []string `json:"links,omitempty"`
}

type candidateScore struct {
	page    *Page
	score   int
	reasons map[string]bool
	snippet string
	links   []string
}

var tokenRe = regexp.MustCompile(`[A-Za-z0-9가-힣][A-Za-z0-9가-힣+.#_-]*`)

func cmdContext(args []string) error {
	fs := flag.NewFlagSet("context", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)
	limit := fs.Int("n", defaultContextLimit, "maximum candidates")
	minScore := fs.Int("min-score", defaultContextMinScore, "minimum score to include")
	mode := fs.String("mode", "query", "query, ingest, or crystallize")
	if err := fs.Parse(args); err != nil {
		return err
	}
	if *limit <= 0 {
		return fmt.Errorf("-n must be positive")
	}
	if *minScore < 0 {
		return fmt.Errorf("-min-score must be non-negative")
	}

	query := strings.TrimSpace(strings.Join(fs.Args(), " "))
	if query == "" {
		return fmt.Errorf("context requires a query string or file path")
	}

	expandedQuery := query
	if data, ok := readContextInput(query); ok {
		expandedQuery = query + "\n" + string(data)
	}

	vault := vaultRoot()
	kbDir := filepath.Join(vault, "kb")
	pages, err := listPages(kbDir)
	if err != nil {
		return err
	}

	candidates := rankContextCandidates(pages, expandedQuery, *limit, *minScore)
	report := contextReport{
		Vault:      vault,
		Query:      query,
		Mode:       *mode,
		Limit:      *limit,
		MinScore:   *minScore,
		Candidates: candidates,
	}
	out, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return err
	}
	os.Stdout.Write(out)
	os.Stdout.Write([]byte("\n"))
	return nil
}

func readContextInput(input string) ([]byte, bool) {
	path := input
	if !filepath.IsAbs(path) {
		path = filepath.Join(vaultRoot(), input)
	}
	info, err := os.Stat(path)
	if err != nil || info.IsDir() {
		return nil, false
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, false
	}
	const maxBytes = 64 * 1024
	if len(data) > maxBytes {
		data = data[:maxBytes]
	}
	return data, true
}

func rankContextCandidates(pages []*Page, query string, limit int, minScore int) []contextCandidate {
	queryNorm := normalizeForContext(query)
	queryCompact := compactForContext(query)
	queryTokens := uniqueTokens(query)

	var scored []candidateScore
	for _, page := range pages {
		score := candidateScore{
			page:    page,
			reasons: map[string]bool{},
		}
		nameCompact := compactForContext(page.Name)
		bodyNorm := normalizeForContext(page.Body)
		bodyCompact := compactForContext(page.Body)
		tagCompact := compactForContext(strings.Join(page.Tags, " "))

		if queryCompact != "" && nameCompact == queryCompact {
			score.score += 120
			score.reasons["exact page name"] = true
		} else if queryCompact != "" && strings.Contains(nameCompact, queryCompact) {
			score.score += 80
			score.reasons["page name contains query"] = true
		}
		if queryNorm != "" && strings.Contains(bodyNorm, queryNorm) {
			score.score += 30
			score.reasons["body phrase match"] = true
		}

		for _, token := range queryTokens {
			if len([]rune(token)) < 2 {
				continue
			}
			tokenCompact := compactForContext(token)
			if tokenCompact == "" {
				continue
			}
			switch {
			case nameCompact == tokenCompact:
				score.score += 50
				score.reasons["page name token match"] = true
			case strings.Contains(nameCompact, tokenCompact):
				score.score += 25
				score.reasons["page name partial match"] = true
			}
			if strings.Contains(tagCompact, tokenCompact) {
				score.score += 8
				score.reasons["tag match"] = true
			}
			count := strings.Count(bodyCompact, tokenCompact)
			if count > 0 {
				if count > 5 {
					count = 5
				}
				score.score += count * 3
				score.reasons["body token match"] = true
				if score.snippet == "" {
					score.snippet = snippetForToken(page.Body, token)
				}
			}
		}

		if score.score < minScore {
			continue
		}
		if score.snippet == "" {
			score.snippet = firstNonEmptyBodyLine(page.Body)
		}
		score.links = firstLinks(page.Body, 6)
		scored = append(scored, score)
	}

	sort.Slice(scored, func(i, j int) bool {
		if scored[i].score != scored[j].score {
			return scored[i].score > scored[j].score
		}
		return scored[i].page.Name < scored[j].page.Name
	})
	if len(scored) > limit {
		scored = scored[:limit]
	}

	out := make([]contextCandidate, 0, len(scored))
	for _, s := range scored {
		reasons := make([]string, 0, len(s.reasons))
		for r := range s.reasons {
			reasons = append(reasons, r)
		}
		sort.Strings(reasons)
		out = append(out, contextCandidate{
			Name:    s.page.Name,
			Path:    filepath.ToSlash(filepath.Join("kb", s.page.Name+".md")),
			Score:   s.score,
			Reasons: reasons,
			Snippet: s.snippet,
			Links:   s.links,
		})
	}
	return out
}

func uniqueTokens(s string) []string {
	seen := map[string]bool{}
	var out []string
	for _, match := range tokenRe.FindAllString(s, -1) {
		token := normalizeForContext(match)
		if token == "" || seen[token] || isStopToken(token) {
			continue
		}
		seen[token] = true
		out = append(out, token)
	}
	return out
}

func isStopToken(token string) bool {
	switch token {
	case "the", "and", "for", "with", "that", "this", "what", "why", "how", "are", "is", "of", "to", "in", "a", "an":
		return true
	case "이", "그", "저", "및", "와", "과", "을", "를", "은", "는", "에", "의", "로", "으로", "뭐야":
		return true
	default:
		return false
	}
}

func normalizeForContext(s string) string {
	return strings.ToLower(strings.TrimSpace(s))
}

func compactForContext(s string) string {
	var b strings.Builder
	for _, r := range normalizeForContext(s) {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r >= '가' && r <= '힣' {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func snippetForToken(body, token string) string {
	tokenNorm := normalizeForContext(token)
	tokenCompact := compactForContext(token)
	for _, line := range strings.Split(body, "\n") {
		lineNorm := normalizeForContext(line)
		lineCompact := compactForContext(line)
		if (tokenNorm != "" && strings.Contains(lineNorm, tokenNorm)) ||
			(tokenCompact != "" && strings.Contains(lineCompact, tokenCompact)) {
			return cleanSnippet(line)
		}
	}
	return ""
}

func firstNonEmptyBodyLine(body string) string {
	for _, line := range strings.Split(body, "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		return cleanSnippet(line)
	}
	return ""
}

func cleanSnippet(s string) string {
	s = strings.Join(strings.Fields(s), " ")
	runes := []rune(s)
	if len(runes) > 280 {
		return string(runes[:280]) + "..."
	}
	return s
}

func firstLinks(body string, limit int) []string {
	seen := map[string]bool{}
	var out []string
	for _, m := range wikilinkRe.FindAllStringSubmatch(body, -1) {
		if len(m) < 2 {
			continue
		}
		target := strings.TrimSpace(m[1])
		if target == "" || seen[target] {
			continue
		}
		seen[target] = true
		out = append(out, target)
		if len(out) >= limit {
			break
		}
	}
	return out
}
