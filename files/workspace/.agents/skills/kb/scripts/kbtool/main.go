package main

import (
	"fmt"
	"os"
	"path/filepath"
)

var cachedVault string

func vaultRoot() string {
	if cachedVault != "" {
		return cachedVault
	}
	if v := os.Getenv("KB_VAULT"); v != "" {
		abs, err := filepath.Abs(v)
		if err == nil {
			cachedVault = abs
		} else {
			cachedVault = v
		}
		return cachedVault
	}
	cachedVault = "/Users/hj/Library/Mobile Documents/iCloud~md~obsidian/Documents/Brain"
	return cachedVault
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: kbtool <command>")
	fmt.Fprintln(os.Stderr, "commands:")
	fmt.Fprintln(os.Stderr, "  context         suggest kb pages to preload for a query or source")
	fmt.Fprintln(os.Stderr, "  lint            run integrity + gap checks, emit JSON")
	fmt.Fprintln(os.Stderr, "  rebuild-index   regenerate kb/INDEX.md")
	fmt.Fprintln(os.Stderr, "  rebuild-sources regenerate kb/.sources")
}

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	var err error
	switch os.Args[1] {
	case "context":
		err = cmdContext(os.Args[2:])
	case "lint":
		err = cmdLint()
	case "rebuild-index":
		err = cmdRebuildIndex()
	case "rebuild-sources":
		err = cmdRebuildSources()
	default:
		usage()
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
