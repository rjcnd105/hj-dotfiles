package main

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// sectionRule maps tag memberships to a named section. Sections are applied
// in order; the first matching rule wins. `glossary` short-circuits everything
// else (see classify).
type sectionRule struct {
	name string
	tags []string
}

var sectionRules = []sectionRule{
	{"Nix / Container", []string{
		"nix", "docker", "podman", "quadlet", "systemd",
		"containers", "container", "nixos",
	}},
	{"Elixir / Phoenix", []string{
		"elixir", "phoenix", "liveview", "ecto",
	}},
	{"CSS", []string{"css"}},
	{"Frontend / JavaScript", []string{
		"javascript", "typescript", "react", "vue", "svelte",
		"frontend", "dom", "browser", "hooks", "state-management",
		"routing", "tanstack",
	}},
	{"Database", []string{
		"database", "postgres", "postgresql", "sqlite", "sql",
		"duckdb", "clickhouse", "cockroachdb", "tigerbeetle",
		"foundationdb", "columnar", "olap", "distributed-systems",
		"distributed-database", "embedded-database", "financial-database",
	}},
	{"AI / LLM", []string{
		"ai", "llm", "ml", "agent", "agents", "rl", "rlhf",
		"transformer", "embedding", "rag", "evolution",
		"self-improvement", "knowledge-graph", "graph-algorithm",
		"clustering",
	}},
	{"Health / Science", []string{
		"health", "science", "pharmacology", "nutrition", "neurology",
		"neuroscience", "biology", "microbiome", "history", "nootropic",
		"supplement", "medication",
	}},
}

// classify returns the section name for a page. Glossary tag wins over all
// other rules; 기타 is the fallback.
func classify(p *Page) string {
	if hasTag(p, "glossary") {
		return "Glossary"
	}
	tagSet := map[string]bool{}
	for _, t := range p.Tags {
		tagSet[t] = true
	}
	for _, r := range sectionRules {
		for _, t := range r.tags {
			if tagSet[t] {
				return r.name
			}
		}
	}
	return "기타"
}

// sectionOrder is the output order used when rendering INDEX.md. Any section
// not listed here is appended at the end preserving discovery order.
var sectionOrder = []string{
	"Nix / Container",
	"Elixir / Phoenix",
	"CSS",
	"Frontend / JavaScript",
	"Database",
	"AI / LLM",
	"Health / Science",
	"Glossary",
	"기타",
}

const indexCreated = "2026-04-07T07:55:00Z"

func cmdRebuildIndex() error {
	vault := vaultRoot()
	kbDir := filepath.Join(vault, "kb")

	pages, err := listPages(kbDir)
	if err != nil {
		return err
	}

	// Classify and group pages.
	grouped := map[string][]*Page{}
	for _, p := range pages {
		s := classify(p)
		grouped[s] = append(grouped[s], p)
	}
	// Sort each section: created desc, then name asc.
	for _, sec := range grouped {
		sort.SliceStable(sec, func(i, j int) bool {
			if !sec[i].Created.Equal(sec[j].Created) {
				return sec[i].Created.After(sec[j].Created)
			}
			return sec[i].Name < sec[j].Name
		})
	}

	// Annotate for health block.
	now := time.Now().UTC()
	annotations := make([]pageAnnotations, len(pages))
	for i, p := range pages {
		annotations[i] = annotate(p, now)
	}
	health := computeHealth(pages, annotations, now)

	// Render.
	var buf strings.Builder
	buf.WriteString("---\n")
	buf.WriteString("publish: false\n")
	fmt.Fprintf(&buf, "created: %s\n", indexCreated)
	fmt.Fprintf(&buf, "modified: %s\n", now.Format("2006-01-02T15:04:05Z"))
	buf.WriteString("tags:\n")
	buf.WriteString("  - kb\n")
	buf.WriteString("  - index\n")
	buf.WriteString("---\n\n")
	buf.WriteString("# KB Index\n\n")
	buf.WriteString("kb/ 페이지의 카탈로그. frontmatter 기반으로 재생성 가능한 캐시. `/kb rebuild-index`로 복구.\n\n")

	// Sections in the canonical order; skip empty sections.
	written := map[string]bool{}
	sectionsRendered := 0
	for _, name := range sectionOrder {
		pgs := grouped[name]
		if len(pgs) == 0 {
			continue
		}
		sectionsRendered++
		written[name] = true
		fmt.Fprintf(&buf, "## %s\n\n", name)
		for _, p := range pgs {
			fmt.Fprintf(&buf, "- [[%s]] — %s\n", p.Name, oneLine(p.Body))
		}
		buf.WriteString("\n")
	}
	// Any section not in the canonical order — append at end.
	var extras []string
	for name := range grouped {
		if !written[name] {
			extras = append(extras, name)
		}
	}
	sort.Strings(extras)
	for _, name := range extras {
		pgs := grouped[name]
		if len(pgs) == 0 {
			continue
		}
		sectionsRendered++
		fmt.Fprintf(&buf, "## %s\n\n", name)
		for _, p := range pgs {
			fmt.Fprintf(&buf, "- [[%s]] — %s\n", p.Name, oneLine(p.Body))
		}
		buf.WriteString("\n")
	}

	// Health block (uses section header "Health", not "Health / Science").
	buf.WriteString("## Health\n\n")
	fmt.Fprintf(&buf, "- 총 페이지: %d\n", health.total)
	fmt.Fprintf(&buf, "- 단일 출처 페이지: %d/%d (출처 없는 페이지 %d 별도)\n",
		health.singleSource, health.total, health.emptySource)
	fmt.Fprintf(&buf, "- 미해결 논쟁: %d\n", health.conflicts)
	fmt.Fprintf(&buf, "- 최신 동향 만료: %d (6개월 기준)\n", health.staleRecent)
	fmt.Fprintf(&buf, "- 고아 페이지: %d (glossary 제외)\n", health.orphans)
	fmt.Fprintf(&buf, "- 마지막 rebuild-index: %s\n", now.Format("2006-01-02"))

	outPath := filepath.Join(kbDir, "INDEX.md")
	if err := atomicWrite(outPath, []byte(buf.String())); err != nil {
		return err
	}
	fmt.Printf("wrote %s (%d pages across %d sections)\n", outPath, len(pages), sectionsRendered)
	return nil
}

type healthStats struct {
	total, singleSource, emptySource, conflicts, staleRecent, orphans int
}

func computeHealth(pages []*Page, annotations []pageAnnotations, now time.Time) healthStats {
	h := healthStats{total: len(pages)}
	internalInbound := map[string]int{}
	for i, p := range pages {
		a := annotations[i]
		if a.SingleSource {
			h.singleSource++
		}
		if a.EmptySource || !p.kbSourcesPresent {
			h.emptySource++
		}
		if a.HasConflict {
			h.conflicts++
		}
		if a.StaleRecent {
			h.staleRecent++
		}
		for _, t := range a.WikilinkTargets {
			if t != p.Name {
				internalInbound[t]++
			}
		}
	}
	_, externalInbound, _ := walkVault(vaultRoot())
	for _, p := range pages {
		if hasTag(p, "glossary") {
			continue
		}
		if internalInbound[p.Name] > 0 {
			continue
		}
		if externalInbound[p.Name] {
			continue
		}
		h.orphans++
	}
	return h
}

// oneLine extracts a one-line description from the body of a page. It skips
// leading blank lines and markdown heading lines, strips wikilink markup
// preserving display text, and returns either the full first paragraph or
// just its first sentence depending on length.
func oneLine(body string) string {
	var para string
	var b strings.Builder
	inPara := false
	for _, line := range strings.Split(body, "\n") {
		trim := strings.TrimSpace(line)
		if !inPara {
			if trim == "" {
				continue
			}
			if strings.HasPrefix(trim, "#") {
				continue
			}
			inPara = true
			b.WriteString(trim)
			continue
		}
		if trim == "" {
			break
		}
		b.WriteString(" ")
		b.WriteString(trim)
	}
	para = b.String()
	// Strip wikilinks: [[page|display]] -> display, [[page]] -> page.
	para = wikilinkRe.ReplaceAllStringFunc(para, func(m string) string {
		sub := wikilinkRe.FindStringSubmatch(m)
		if len(sub) >= 3 && sub[2] != "" {
			return sub[2]
		}
		if len(sub) >= 2 {
			return sub[1]
		}
		return m
	})

	// Collapse runs of whitespace to a single space so we compare consistent
	// byte lengths (the original also does strings.Fields / strings.Join).
	para = strings.Join(strings.Fields(strings.ReplaceAll(para, "\n", " ")), " ")

	const maxBytes = 200
	if len(para) <= maxBytes {
		return para
	}
	// Over budget: truncate at the first sentence boundary, but only when the
	// boundary sits within [21, 200). Anything else (abbreviations like `J.`
	// producing tiny idx values, or a single huge run-on sentence) keeps the
	// full paragraph.
	if idx := strings.Index(para, ". "); idx >= 21 && idx < 200 {
		return para[:idx]
	}
	return para
}

// atomicWrite writes data to path via a temp file in the same directory and a
// rename, so partial writes never land on disk.
func atomicWrite(path string, data []byte) error {
	dir := filepath.Dir(path)
	f, err := os.CreateTemp(dir, ".tmp-INDEX-*")
	if err != nil {
		return err
	}
	tmp := f.Name()
	if _, err := f.Write(data); err != nil {
		f.Close()
		os.Remove(tmp)
		return err
	}
	if err := f.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return err
	}
	return nil
}
