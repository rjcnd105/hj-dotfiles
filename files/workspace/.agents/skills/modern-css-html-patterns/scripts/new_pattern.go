package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

var newPatternID = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)

func main() {
	if len(os.Args) != 3 {
		fmt.Fprintln(os.Stderr, "usage: go run scripts/new_pattern.go <pattern-id> \"<Pattern Title>\"")
		os.Exit(2)
	}

	id := os.Args[1]
	title := os.Args[2]
	if !newPatternID.MatchString(id) {
		fmt.Fprintln(os.Stderr, "pattern-id must be kebab-case")
		os.Exit(2)
	}

	root, err := skillRoot()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	replacements := map[string]string{
		"{{ID}}":    id,
		"{{TITLE}}": title,
	}

	targets := []struct {
		template string
		target   string
	}{
		{
			template: filepath.Join(root, "templates", "pattern.md"),
			target:   filepath.Join(root, "references", "patterns", id+".md"),
		},
		{
			template: filepath.Join(root, "templates", "example.html"),
			target:   filepath.Join(root, "examples", id, "index.html"),
		},
		{
			template: filepath.Join(root, "templates", "code-kernel.md"),
			target:   filepath.Join(root, "references", "code-kernels", id+".md"),
		},
	}

	for _, item := range targets {
		if fileExists(item.target) {
			fmt.Fprintf(os.Stderr, "ERROR: refusing to overwrite %s\n", rel(root, item.target))
			os.Exit(1)
		}
	}

	for _, item := range targets {
		content, err := os.ReadFile(item.template)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: read template %s: %v\n", rel(root, item.template), err)
			os.Exit(1)
		}
		text := string(content)
		for from, to := range replacements {
			text = strings.ReplaceAll(text, from, to)
		}
		if err := os.MkdirAll(filepath.Dir(item.target), 0o755); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: create directory for %s: %v\n", rel(root, item.target), err)
			os.Exit(1)
		}
		if err := os.WriteFile(item.target, []byte(text), 0o644); err != nil {
			fmt.Fprintf(os.Stderr, "ERROR: write %s: %v\n", rel(root, item.target), err)
			os.Exit(1)
		}
		fmt.Println("created", rel(root, item.target))
	}

	fmt.Println()
	fmt.Println("Next steps:")
	fmt.Println("- Append source events to logs/ingest.jsonl and references/source-seeds.jsonl.")
	fmt.Println("- Add one catalog line to references/index.jsonl with code_kernel_path.")
	fmt.Println("- Replace the code-kernel placeholder.")
	fmt.Println("- Replace placeholder prose and HTML.")
	fmt.Println("- Run: go run scripts/validate_index.go")
}

func skillRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	candidates := []string{
		cwd,
		filepath.Join(cwd, "files", "workspace", ".agents", "skills", "modern-css-html-patterns"),
	}
	_, sourceFile, _, ok := runtime.Caller(0)
	if ok {
		candidates = append(candidates, filepath.Dir(filepath.Dir(sourceFile)))
	}
	for _, candidate := range candidates {
		if fileExists(filepath.Join(candidate, "SKILL.md")) &&
			fileExists(filepath.Join(candidate, "references", "index.jsonl")) {
			return candidate, nil
		}
	}
	return "", fmt.Errorf("could not find modern-css-html-patterns skill root from %s", cwd)
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func rel(root, path string) string {
	relative, err := filepath.Rel(root, path)
	if err != nil {
		return path
	}
	return relative
}
