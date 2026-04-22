package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func writeTempFixture(t *testing.T, body string) string {
	t.Helper()
	dir := t.TempDir()
	p := filepath.Join(dir, "fixtures.yaml")
	if err := os.WriteFile(p, []byte(body), 0600); err != nil {
		t.Fatalf("write fixture: %v", err)
	}
	return p
}

const validFixtures = `
version: 1
bank: "::nix-dots"
fixtures:
  - id: "fx-001"
    query: "q1"
    expected_memory_ids: ["a", "b"]
    description: "d1"
    tags: ["t1"]
  - id: "fx-002"
    query: "q2"
    expected_memory_ids: ["c"]
    description: "d2"
`

func TestLoadFixtures_HappyPath(t *testing.T) {
	path := writeTempFixture(t, validFixtures)
	set, err := LoadFixtures(path)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if set.Version != 1 || set.Bank != "::nix-dots" {
		t.Fatalf("header wrong: %+v", set)
	}
	if got := len(set.Fixtures); got != 2 {
		t.Fatalf("want 2 fixtures, got %d", got)
	}
	if set.VersionHash == "" {
		t.Fatal("VersionHash must be populated")
	}
}

func TestLoadFixtures_RejectsDuplicateID(t *testing.T) {
	body := `
version: 1
bank: b
fixtures:
  - id: fx-001
    query: q
    expected_memory_ids: [a]
  - id: fx-001
    query: q2
    expected_memory_ids: [b]
`
	path := writeTempFixture(t, body)
	_, err := LoadFixtures(path)
	if err == nil || !strings.Contains(err.Error(), "duplicate fixture id") {
		t.Fatalf("want duplicate error, got %v", err)
	}
}

func TestLoadFixtures_RejectsEmptyExpected(t *testing.T) {
	body := `
version: 1
bank: b
fixtures:
  - id: fx-001
    query: q
    expected_memory_ids: []
`
	path := writeTempFixture(t, body)
	_, err := LoadFixtures(path)
	if err == nil || !strings.Contains(err.Error(), "expected_memory_ids cannot be empty") {
		t.Fatalf("want empty-expected error, got %v", err)
	}
}

func TestLoadFixtures_RejectsExampleSentinel(t *testing.T) {
	body := `
version: 1
bank: b
fixtures:
  - id: fx-001
    query: q
    expected_memory_ids:
      - "[EXAMPLE ONLY — replace with real memory UUID]"
`
	path := writeTempFixture(t, body)
	_, err := LoadFixtures(path)
	if err == nil || !strings.Contains(err.Error(), "example sentinel") {
		t.Fatalf("want sentinel error, got %v", err)
	}
}

func TestLoadFixtures_RejectsUnknownVersion(t *testing.T) {
	body := `
version: 2
bank: b
fixtures:
  - id: fx-001
    query: q
    expected_memory_ids: [a]
`
	path := writeTempFixture(t, body)
	_, err := LoadFixtures(path)
	if err == nil || !strings.Contains(err.Error(), "unsupported fixtures version") {
		t.Fatalf("want version error, got %v", err)
	}
}
