package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// E2E 스텁: podman/systemctl을 PATH 스텁으로 바꿔 전체 deploy 트랜잭션을
// 검증한다 (성공 → no-op → migration 실패 복구).
func TestDeployTransactionWithStubs(t *testing.T) {
	if os.Geteuid() == 0 {
		t.Skip("stub transaction test must run unprivileged")
	}
	work := t.TempDir()
	binDir := filepath.Join(work, "bin")
	stateDir := filepath.Join(work, "state")
	metaDir := filepath.Join(work, "metadata")
	stubState := filepath.Join(work, "stub-state")
	stubLog := filepath.Join(work, "commands.log")
	manifestDir := filepath.Join(work, "manifests")
	for _, dir := range []string{binDir, stateDir, filepath.Join(metaDir, "deopjib"), stubState, manifestDir} {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			t.Fatal(err)
		}
	}

	writeStub := func(name, body string) {
		script := "#!/bin/sh\n" + body
		if err := os.WriteFile(filepath.Join(binDir, name), []byte(script), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	writeStub("podman", `echo "podman $*" >> "$STUB_LOG"
case "$1" in
  image)
    ref=$3
    case "$ref" in
      *backend:dev-current) cat "$STUB_STATE/backend" 2>/dev/null || true ;;
      *web:dev-current) cat "$STUB_STATE/web" 2>/dev/null || true ;;
      *@sha256:*) printf 'digest-id\n' ;;
      *) printf 'db-pinned\n' ;;
    esac
    ;;
  pull) : ;;
  tag)
    case "$3" in
      *backend:dev-current) printf '%s\n' "$2" > "$STUB_STATE/backend" ;;
      *web:dev-current) printf '%s\n' "$2" > "$STUB_STATE/web" ;;
      *) exit 1 ;;
    esac
    ;;
  untag) : ;;
  images) : ;;
  rmi) : ;;
  *) exit 1 ;;
esac
`)
	writeStub("systemctl", `echo "systemctl $*" >> "$STUB_LOG"
if [ "$1" = start ] && [ "${STUB_FAIL_MIGRATION:-0}" = 1 ]; then
  exit 1
fi
exit 0
`)
	writeStub("sha256sum", `exit 0
`)

	smoke := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer smoke.Close()

	writeManifest := func(target string) {
		manifest := v1Manifest(target)
		data, err := json.Marshal(manifest)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(manifestDir, target+".json"), data, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	writeManifest("deopjib-v1.0.0")
	writeManifest("deopjib-v1.0.1")

	meta := v1Metadata()
	meta.AppKey = "deopjib"
	meta.UnitPrefix = "deopjib-dev"
	meta.Domain = "dev.deopjib.site"
	meta.CaddyURL = smoke.URL
	meta.SmokePaths = []string{"/health"}
	meta.Migration = MigrationMeta{Mode: "manual", Service: "backend", Unit: "deopjib-dev-migrate.service", Command: []string{"/app/bin/migrate"}}
	meta.Release.ManifestURL = "file://" + manifestDir + "/{target}.json"
	metaBytes, err := json.Marshal(meta)
	if err != nil {
		t.Fatal(err)
	}
	metaPath := filepath.Join(metaDir, "deopjib", "dev.json")
	if err := os.WriteFile(metaPath, metaBytes, 0o644); err != nil {
		t.Fatal(err)
	}

	t.Setenv("PATH", binDir+":"+os.Getenv("PATH"))
	t.Setenv("STUB_LOG", stubLog)
	t.Setenv("STUB_STATE", stubState)
	t.Setenv("HOMELAB_APPCTL_METADATA_ROOT", metaDir)
	t.Setenv("HOMELAB_APPCTL_STATE_ROOT", stateDir)
	t.Setenv("HOMELAB_APPCTL_TEST_ALLOW_FILE_URL", "1")

	os.WriteFile(filepath.Join(stubState, "backend"), []byte("backend-old\n"), 0o644)
	os.WriteFile(filepath.Join(stubState, "web"), []byte("web-old\n"), 0o644)

	loaded, err := loadMetadata("deopjib", "dev")
	if err != nil {
		t.Fatal(err)
	}

	// 1. 성공 트랜잭션.
	if err := cmdDeploy(loaded, "deopjib", "dev", "deopjib-v1.0.0"); err != nil {
		t.Fatalf("deploy failed: %v", err)
	}
	latest := filepath.Join(stateDir, "deopjib", "dev", "latest")
	result, _ := os.ReadFile(filepath.Join(latest, "result"))
	if strings.TrimSpace(string(result)) != "ok" {
		t.Fatalf("expected ok result, got %q", result)
	}
	log := readFile(t, stubLog)
	if got := strings.Count(log, "systemctl restart"); got != 1 {
		t.Fatalf("expected exactly one restart transaction, got %d\n%s", got, log)
	}
	if !strings.Contains(log, "systemctl restart deopjib-dev-backend.service deopjib-dev-web.service") {
		t.Fatalf("release units not restarted together:\n%s", log)
	}
	if strings.Contains(log, "deopjib-dev-db.service") {
		t.Fatalf("pinned database service touched:\n%s", log)
	}
	if got := strings.Count(log, "systemctl start deopjib-dev-migrate.service"); got != 1 {
		t.Fatalf("expected exactly one migration start, got %d", got)
	}
	if got := strings.Count(log, "podman pull"); got != 2 {
		t.Fatalf("expected 2 pulls, got %d", got)
	}

	// 2. 같은 target 재요청은 no-op.
	before := readFile(t, stubLog)
	if err := cmdDeploy(loaded, "deopjib", "dev", "deopjib-v1.0.0"); err != nil {
		t.Fatalf("no-op deploy failed: %v", err)
	}
	if readFile(t, stubLog) != before {
		t.Fatalf("no-op deploy executed commands")
	}

	// 3. migration 실패 시 이전 태그 복원.
	previousBackend := readFile(t, filepath.Join(stubState, "backend"))
	previousWeb := readFile(t, filepath.Join(stubState, "web"))
	t.Setenv("STUB_FAIL_MIGRATION", "1")
	if err := cmdDeploy(loaded, "deopjib", "dev", "deopjib-v1.0.1"); err == nil {
		t.Fatalf("migration failure unexpectedly succeeded")
	}
	t.Setenv("STUB_FAIL_MIGRATION", "0")
	result, _ = os.ReadFile(filepath.Join(latest, "result"))
	if strings.TrimSpace(string(result)) != "migration-failed" {
		t.Fatalf("expected migration-failed, got %q", result)
	}
	if readFile(t, filepath.Join(stubState, "backend")) != previousBackend {
		t.Fatalf("backend tag not restored after migration failure")
	}
	if readFile(t, filepath.Join(stubState, "web")) != previousWeb {
		t.Fatalf("web tag not restored after migration failure")
	}
}

func TestPruneDeployRecords(t *testing.T) {
	dir := t.TempDir()
	for i := 0; i < keepDeployRecords+3; i++ {
		name := fmt.Sprintf("20260828T%06dZ.aaaaaa", i)
		if err := os.MkdirAll(filepath.Join(dir, name), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	os.MkdirAll(filepath.Join(dir, "not-a-record"), 0o755)
	pruneDeployRecords(dir)

	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	var records []string
	for _, entry := range entries {
		if entry.Name() != "not-a-record" {
			records = append(records, entry.Name())
		}
	}
	if len(records) != keepDeployRecords {
		t.Fatalf("expected %d records kept, got %d", keepDeployRecords, len(records))
	}
	// 최신 레코드가 남아 있어야 한다.
	newest := fmt.Sprintf("20260828T%06dZ.aaaaaa", keepDeployRecords+2)
	if _, err := os.Stat(filepath.Join(dir, newest)); err != nil {
		t.Fatalf("newest record was pruned")
	}
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
