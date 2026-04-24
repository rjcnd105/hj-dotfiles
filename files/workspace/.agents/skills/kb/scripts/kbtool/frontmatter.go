package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Page is a parsed kb/*.md page.
type Page struct {
	Name             string   // file stem without extension
	Path             string   // absolute path
	KBType           string   // kb-type
	Created          time.Time
	CreatedRaw       string
	Modified         time.Time
	ModifiedRaw      string
	Tags             []string
	KBSources        []string // nil if absent, empty slice if declared empty
	kbSourcesPresent bool
	KBContradictions int
	Body             string
}

// pageAnnotations are derived per-page facts used by lint + rebuild-index.
type pageAnnotations struct {
	EmptySource      bool
	SingleSource     bool
	HasConflict      bool
	StaleRecent      bool
	StaleSections    []string
	WikilinkTargets  []string
}

var (
	wikilinkRe  = regexp.MustCompile(`\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]`)
	recentHdrRe = regexp.MustCompile(`(?m)^##\s+최신 동향\s*\((\d{4}-\d{2})\)`)
)

var metaFiles = map[string]struct{}{
	"SCHEMA.md":  {},
	"INDEX.md":   {},
	"LOG.md":     {},
	"ROADMAP.md": {},
}

// listPages returns parsed pages from kb/*.md at depth 1.
func listPages(kbDir string) ([]*Page, error) {
	entries, err := os.ReadDir(kbDir)
	if err != nil {
		return nil, fmt.Errorf("list pages: %w", err)
	}
	var pages []*Page
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		name := e.Name()
		if strings.HasPrefix(name, ".") {
			continue
		}
		if !strings.HasSuffix(name, ".md") {
			continue
		}
		if _, skip := metaFiles[name]; skip {
			continue
		}
		p, err := readPage(filepath.Join(kbDir, name))
		if err != nil {
			return nil, err
		}
		pages = append(pages, p)
	}
	sort.Slice(pages, func(i, j int) bool { return pages[i].Name < pages[j].Name })
	return pages, nil
}

// readPage parses a single page file.
func readPage(path string) (*Page, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 0, 64*1024), 8*1024*1024)

	page := &Page{
		Path: path,
		Name: strings.TrimSuffix(filepath.Base(path), ".md"),
	}

	// Must start with ---
	if !sc.Scan() {
		return page, nil
	}
	if strings.TrimSpace(sc.Text()) != "---" {
		// No frontmatter; treat whole file as body.
		var b strings.Builder
		b.WriteString(sc.Text())
		b.WriteString("\n")
		for sc.Scan() {
			b.WriteString(sc.Text())
			b.WriteString("\n")
		}
		page.Body = b.String()
		return page, nil
	}

	// Collect frontmatter lines.
	var fmLines []string
	for sc.Scan() {
		line := sc.Text()
		if strings.TrimSpace(line) == "---" {
			break
		}
		fmLines = append(fmLines, line)
	}

	parseFrontmatter(page, fmLines)

	// Body is everything after the closing ---
	var b strings.Builder
	for sc.Scan() {
		b.WriteString(sc.Text())
		b.WriteString("\n")
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	page.Body = b.String()
	return page, nil
}

// parseFrontmatter fills page with values from the YAML frontmatter lines.
// Only block-form arrays are supported; inline [] is tolerated as empty.
func parseFrontmatter(page *Page, lines []string) {
	i := 0
	for i < len(lines) {
		line := lines[i]
		trim := strings.TrimSpace(line)
		if trim == "" || strings.HasPrefix(trim, "#") {
			i++
			continue
		}
		// Expect "key: value" at indent 0.
		colon := strings.Index(line, ":")
		if colon < 0 || len(line) > 0 && (line[0] == ' ' || line[0] == '\t') {
			i++
			continue
		}
		key := strings.TrimSpace(line[:colon])
		value := strings.TrimSpace(line[colon+1:])

		switch key {
		case "kb-type":
			page.KBType = unquote(value)
		case "created":
			page.CreatedRaw = unquote(value)
			page.Created = parseTime(page.CreatedRaw)
		case "modified":
			page.ModifiedRaw = unquote(value)
			page.Modified = parseTime(page.ModifiedRaw)
		case "kb-contradictions":
			n, err := strconv.Atoi(unquote(value))
			if err == nil {
				page.KBContradictions = n
			}
		case "tags":
			items, consumed := parseBlockOrInline(lines, i, value)
			page.Tags = items
			i += consumed
			continue
		case "kb-sources":
			items, consumed := parseBlockOrInline(lines, i, value)
			page.KBSources = items
			page.kbSourcesPresent = true
			if items == nil {
				page.KBSources = []string{}
			}
			i += consumed
			continue
		}
		i++
	}
}

// parseBlockOrInline returns the block items starting at index i. If the value
// on the key line is inline (e.g. [a, b] or []), it is parsed from that line.
// Returns (items, linesConsumed). linesConsumed >= 1.
func parseBlockOrInline(lines []string, i int, value string) ([]string, int) {
	if value != "" {
		// Inline form: either `[]`, `[a, b]`, or a scalar.
		if value == "[]" {
			return []string{}, 1
		}
		if strings.HasPrefix(value, "[") && strings.HasSuffix(value, "]") {
			inner := strings.TrimSpace(value[1 : len(value)-1])
			if inner == "" {
				return []string{}, 1
			}
			var out []string
			for _, part := range strings.Split(inner, ",") {
				out = append(out, unquote(strings.TrimSpace(part)))
			}
			return out, 1
		}
		// Scalar on same line (uncommon for tags/kb-sources).
		return []string{unquote(value)}, 1
	}
	// Block form.
	var items []string
	j := i + 1
	for j < len(lines) {
		l := lines[j]
		trim := strings.TrimSpace(l)
		if trim == "" {
			j++
			continue
		}
		if !(strings.HasPrefix(l, " ") || strings.HasPrefix(l, "\t")) {
			break
		}
		if strings.HasPrefix(trim, "- ") {
			items = append(items, unquote(strings.TrimSpace(trim[2:])))
			j++
			continue
		}
		if trim == "-" {
			items = append(items, "")
			j++
			continue
		}
		// Indented non-list line, stop.
		break
	}
	if items == nil {
		// Key with no items — treat as empty.
		return []string{}, j - i
	}
	return items, j - i
}

// unquote strips surrounding matching quotes (single or double) from a scalar.
func unquote(s string) string {
	if len(s) >= 2 {
		if (s[0] == '"' && s[len(s)-1] == '"') || (s[0] == '\'' && s[len(s)-1] == '\'') {
			return s[1 : len(s)-1]
		}
	}
	return s
}

// parseTime parses RFC3339 strings, falling back to a few common layouts.
func parseTime(s string) time.Time {
	layouts := []string{
		time.RFC3339,
		"2006-01-02T15:04:05Z",
		"2006-01-02T15:04:05",
		"2006-01-02",
	}
	for _, l := range layouts {
		if t, err := time.Parse(l, s); err == nil {
			return t
		}
	}
	return time.Time{}
}

// hasTag reports whether the page has the given tag.
func hasTag(p *Page, tag string) bool {
	for _, t := range p.Tags {
		if t == tag {
			return true
		}
	}
	return false
}

// annotate computes derived facts for a page.
func annotate(p *Page, now time.Time) pageAnnotations {
	a := pageAnnotations{}
	if p.kbSourcesPresent && len(p.KBSources) == 0 {
		a.EmptySource = true
	}
	if len(p.KBSources) == 1 {
		a.SingleSource = true
	}
	if strings.Contains(p.Body, "[!warning] 논쟁") {
		a.HasConflict = true
	}
	// Find recent-trend sections and check staleness.
	for _, m := range recentHdrRe.FindAllStringSubmatch(p.Body, -1) {
		if len(m) < 2 {
			continue
		}
		if isStale(m[1], now) {
			a.StaleRecent = true
			a.StaleSections = append(a.StaleSections, fmt.Sprintf("%s (%s)", p.Name, m[1]))
		}
	}
	// Wikilink targets — cheap guard before running regex.
	if strings.Contains(p.Body, "[[") {
		for _, m := range wikilinkRe.FindAllStringSubmatch(p.Body, -1) {
			if len(m) >= 2 {
				a.WikilinkTargets = append(a.WikilinkTargets, strings.TrimSpace(m[1]))
			}
		}
	}
	return a
}

// isStale reports whether yyyy-mm is older than 180 days before now.
func isStale(yyyymm string, now time.Time) bool {
	t, err := time.Parse("2006-01", yyyymm)
	if err != nil {
		return false
	}
	return now.Sub(t) > 180*24*time.Hour
}
