package main

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"
)

func cmdRebuildSources() error {
	vault := vaultRoot()
	kbDir := filepath.Join(vault, "kb")

	pages, err := listPages(kbDir)
	if err != nil {
		return err
	}

	seen := map[string]bool{}
	for _, p := range pages {
		for _, src := range p.KBSources {
			if strings.HasPrefix(src, "Clippings/") || strings.HasPrefix(src, "session:") {
				seen[src] = true
			}
		}
	}

	sources := make([]string, 0, len(seen))
	for src := range seen {
		sources = append(sources, src)
	}
	sort.Strings(sources)

	var b strings.Builder
	for _, src := range sources {
		b.WriteString(src)
		b.WriteString("\n")
	}

	outPath := filepath.Join(kbDir, ".sources")
	if err := atomicWrite(outPath, []byte(b.String())); err != nil {
		return err
	}
	fmt.Printf("wrote %s (%d entries)\n", outPath, len(sources))
	return nil
}
