package main

import (
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

type brokenWikilink struct {
	Page   string `json:"page"`
	Target string `json:"target"`
}

type frontmatterViolation struct {
	Page  string `json:"page"`
	Issue string `json:"issue"`
}

type deadSourceRef struct {
	Page   string `json:"page"`
	Source string `json:"source"`
}

type roadmapInfo struct {
	Exists       bool   `json:"exists"`
	PageCount    int    `json:"page_count"`
	RawFirstLine string `json:"raw_first_line"`
}

// lintReport is emitted as JSON. All null-when-empty slices are handled
// manually via custom MarshalJSON.
type lintReport struct {
	Vault                 string                 `json:"vault"`
	Generated             string                 `json:"generated"`
	TotalPages            int                    `json:"total_pages"`
	BrokenWikilinks       []brokenWikilink       `json:"broken_wikilinks"`
	FrontmatterViolations []frontmatterViolation `json:"frontmatter_violations"`
	DeadSourceRefs        []deadSourceRef        `json:"dead_source_refs"`
	SingleSourcePages     []string               `json:"single_source_pages"`
	EmptySourcePages      []string               `json:"empty_source_pages"`
	UnresolvedConflicts   []string               `json:"unresolved_conflicts"`
	UnprocessedClippings  []string               `json:"unprocessed_clippings"`
	StaleRecentSections   []string               `json:"stale_recent_sections"`
	OrphanPages           []string               `json:"orphan_pages"`
	ClassifyDifficult     []string               `json:"classify_difficult"`
	Roadmap               roadmapInfo            `json:"roadmap"`
}

// MarshalJSON emits null for empty/nil slices so downstream consumers can
// distinguish absence from presence.
func (r lintReport) MarshalJSON() ([]byte, error) {
	type alias lintReport
	a := alias(r)
	// Preserve non-nil empties for the list fields that always appear.
	if a.SingleSourcePages == nil {
		a.SingleSourcePages = []string{}
	}
	if a.EmptySourcePages == nil {
		a.EmptySourcePages = []string{}
	}
	if a.UnresolvedConflicts == nil {
		a.UnresolvedConflicts = []string{}
	}
	if a.UnprocessedClippings == nil {
		a.UnprocessedClippings = []string{}
	}
	// Nil-emitted fields: keep nil → null.
	if len(a.BrokenWikilinks) == 0 {
		a.BrokenWikilinks = nil
	}
	if len(a.FrontmatterViolations) == 0 {
		a.FrontmatterViolations = nil
	}
	if len(a.DeadSourceRefs) == 0 {
		a.DeadSourceRefs = nil
	}
	if len(a.StaleRecentSections) == 0 {
		a.StaleRecentSections = nil
	}
	if len(a.OrphanPages) == 0 {
		a.OrphanPages = nil
	}
	if len(a.ClassifyDifficult) == 0 {
		a.ClassifyDifficult = nil
	}
	return json.Marshal(a)
}

func cmdLint() error {
	vault := vaultRoot()
	kbDir := filepath.Join(vault, "kb")
	now := time.Now().UTC()

	pages, err := listPages(kbDir)
	if err != nil {
		return err
	}

	report := lintReport{
		Vault:      vault,
		Generated:  now.Format("2006-01-02T15:04:05Z"),
		TotalPages: len(pages),
	}

	// Per-page annotations and aggregation.
	annotations := make([]pageAnnotations, len(pages))
	for i, p := range pages {
		annotations[i] = annotate(p, now)
		a := annotations[i]
		if a.SingleSource {
			report.SingleSourcePages = append(report.SingleSourcePages, p.Name)
		}
		// empty_source_pages: treat field-absent the same as field-empty;
		// glossary tag does not exempt.
		if a.EmptySource || (!p.kbSourcesPresent) {
			report.EmptySourcePages = append(report.EmptySourcePages, p.Name)
		}
		if a.HasConflict {
			report.UnresolvedConflicts = append(report.UnresolvedConflicts, p.Name)
		}
		if len(a.StaleSections) > 0 {
			report.StaleRecentSections = append(report.StaleRecentSections, a.StaleSections...)
		}
	}
	sort.Strings(report.SingleSourcePages)
	sort.Strings(report.EmptySourcePages)
	sort.Strings(report.UnresolvedConflicts)

	// Clippings processing.
	clippingsDir := filepath.Join(vault, "Clippings")
	clippings, err := listClippings(clippingsDir)
	if err != nil && !os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "warn: Clippings: %v\n", err)
	}
	used := map[string]bool{}
	for _, p := range pages {
		for _, s := range p.KBSources {
			if strings.HasPrefix(s, "Clippings/") {
				used[strings.TrimPrefix(s, "Clippings/")] = true
			}
		}
	}
	for _, c := range clippings {
		if !used[c] {
			report.UnprocessedClippings = append(report.UnprocessedClippings, c)
		}
	}
	sort.Strings(report.UnprocessedClippings)

	// Vault walk for inbound links and all-md-names.
	_, externalInbound, err := walkVault(vault)
	if err != nil {
		fmt.Fprintf(os.Stderr, "warn: vault walk: %v\n", err)
	}

	// Orphan pages: no other page wikilinks to us, AND no external inbound,
	// AND page is not tagged glossary.
	internalInbound := map[string]int{}
	for i, p := range pages {
		for _, t := range annotations[i].WikilinkTargets {
			if t != p.Name {
				internalInbound[t]++
			}
		}
	}
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
		report.OrphanPages = append(report.OrphanPages, p.Name)
	}
	sort.Strings(report.OrphanPages)

	// Roadmap.
	roadmapPath := filepath.Join(kbDir, "ROADMAP.md")
	info := roadmapInfo{PageCount: len(pages)}
	if data, err := os.ReadFile(roadmapPath); err == nil {
		info.Exists = true
		for _, line := range strings.SplitN(string(data), "\n", 2) {
			info.RawFirstLine = strings.TrimSpace(line)
			break
		}
	} else if !os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "warn: ROADMAP.md: %v\n", err)
	}
	report.Roadmap = info

	out, err := json.MarshalIndent(report, "", "  ")
	if err != nil {
		return err
	}
	os.Stdout.Write(out)
	os.Stdout.Write([]byte("\n"))
	return nil
}

// listClippings returns .md file names directly inside the Clippings dir.
// Dot-prefixed files are skipped.
func listClippings(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var out []string
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
		out = append(out, name)
	}
	return out, nil
}

// walkVault scans the vault for .md files outside kb/, returning every .md
// stem and which kb page names appear as [[wikilink]] targets from outside kb/.
func walkVault(vault string) (allNames map[string]bool, externalInbound map[string]bool, err error) {
	allNames = map[string]bool{}
	externalInbound = map[string]bool{}

	kbDir := filepath.Join(vault, "kb")
	err = filepath.WalkDir(vault, func(path string, d fs.DirEntry, werr error) error {
		if werr != nil {
			return nil
		}
		if d.IsDir() {
			name := d.Name()
			if path == vault {
				return nil
			}
			if strings.HasPrefix(name, ".") {
				return fs.SkipDir
			}
			if name == "node_modules" || name == "trash" {
				return fs.SkipDir
			}
			return nil
		}
		name := d.Name()
		if !strings.HasSuffix(name, ".md") {
			return nil
		}
		if strings.HasPrefix(name, ".") {
			return nil
		}
		stem := strings.TrimSuffix(name, ".md")
		allNames[stem] = true

		// External inbound: only files outside kb/ contribute.
		rel, err := filepath.Rel(kbDir, path)
		inKB := err == nil && !strings.HasPrefix(rel, "..")
		if inKB {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		if !strings.Contains(string(data), "[[") {
			return nil
		}
		for _, m := range wikilinkRe.FindAllStringSubmatch(string(data), -1) {
			if len(m) >= 2 {
				externalInbound[strings.TrimSpace(m[1])] = true
			}
		}
		return nil
	})
	return allNames, externalInbound, err
}
