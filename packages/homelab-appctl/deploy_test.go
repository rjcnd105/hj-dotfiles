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

func readSummary(t *testing.T, dir string) deploySummary {
	t.Helper()
	var s deploySummary
	data := readFile(t, filepath.Join(dir, "summary.json"))
	if err := json.Unmarshal([]byte(data), &s); err != nil {
		t.Fatalf("parse summary.json: %v", err)
	}
	return s
}

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
	migrateCapture := filepath.Join(work, "migrate-image.txt")
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
      *) exit 1 ;;
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
if [ "$1" = start ]; then
  cat "$HOMELAB_APPCTL_STATE_ROOT/run/deopjib-dev-migrate.image" > "$MIGRATE_CAPTURE" 2>/dev/null || true
  if [ "${STUB_FAIL_MIGRATION:-0}" = 1 ]; then
    exit 1
  fi
fi
exit 0
`)

	smoke := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))
	defer smoke.Close()

	writeManifest := func(target string) {
		data, err := json.Marshal(v2Manifest(target))
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(manifestDir, target+".json"), data, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	writeManifest("deopjib-v1.0.0")
	writeManifest("deopjib-v1.0.1")

	meta := v2Metadata()
	meta.CaddyURL = smoke.URL
	meta.Migration = MigrationMeta{Mode: "manual", Service: "backend", Unit: "deopjib-dev-migrate.service", Command: []string{"/app/bin/migrate"}}
	meta.Release.ManifestURL = "file://" + manifestDir + "/{target}.json"
	metaBytes, err := json.Marshal(meta)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(metaDir, "deopjib", "dev.json"), metaBytes, 0o644); err != nil {
		t.Fatal(err)
	}

	t.Setenv("PATH", binDir+":"+os.Getenv("PATH"))
	t.Setenv("STUB_LOG", stubLog)
	t.Setenv("STUB_STATE", stubState)
	t.Setenv("MIGRATE_CAPTURE", migrateCapture)
	t.Setenv("HOMELAB_APPCTL_METADATA_ROOT", metaDir)
	t.Setenv("HOMELAB_APPCTL_STATE_ROOT", stateDir)
	t.Setenv("HOMELAB_APPCTL_TEST_ALLOW_FILE_URL", "1")

	os.WriteFile(filepath.Join(stubState, "backend"), []byte("backend-old\n"), 0o644)
	os.WriteFile(filepath.Join(stubState, "web"), []byte("web-old\n"), 0o644)

	loaded, err := loadMetadata("deopjib", "dev")
	if err != nil {
		t.Fatal(err)
	}
	latest := filepath.Join(stateDir, "deopjib", "dev", "latest")

	t.Run("success_migrates_by_digest_before_tag", func(t *testing.T) {
		if err := cmdDeploy(loaded, "deopjib", "dev", "deopjib-v1.0.0"); err != nil {
			t.Fatalf("deploy failed: %v", err)
		}
		summary := readSummary(t, latest)
		if summary.Result != "ok" || summary.Target != "deopjib-v1.0.0" {
			t.Fatalf("unexpected summary: %+v", summary)
		}
		if got := strings.TrimSpace(readFile(t, migrateCapture)); got != "ghcr.io/x/backend@sha256:"+hexA {
			t.Fatalf("migration did not receive exact digest: %q", got)
		}
		log := readFile(t, stubLog)
		migIdx := strings.Index(log, "systemctl start deopjib-dev-migrate.service")
		tagIdx := strings.Index(log, "podman tag ")
		if migIdx < 0 || tagIdx < 0 || migIdx > tagIdx {
			t.Fatalf("expected migration before podman tag:\n%s", log)
		}
		if got := strings.Count(log, "systemctl restart"); got != 1 {
			t.Fatalf("expected one restart transaction, got %d\n%s", got, log)
		}
		if !strings.Contains(log, "systemctl restart deopjib-dev-backend.service deopjib-dev-web.service") {
			t.Fatalf("release units not restarted together:\n%s", log)
		}
		if got := strings.Count(log, "podman pull"); got != 2 {
			t.Fatalf("expected 2 pulls, got %d", got)
		}
	})

	t.Run("noop_same_target", func(t *testing.T) {
		before := readFile(t, stubLog)
		if err := cmdDeploy(loaded, "deopjib", "dev", "deopjib-v1.0.0"); err != nil {
			t.Fatalf("no-op deploy failed: %v", err)
		}
		if readFile(t, stubLog) != before {
			t.Fatalf("no-op deploy executed commands")
		}
	})

	t.Run("failed_download_preserves_running_latest", func(t *testing.T) {
		before := readFile(t, stubLog)
		if err := cmdDeploy(loaded, "deopjib", "dev", "deopjib-v9.9.9"); err == nil {
			t.Fatalf("missing manifest unexpectedly succeeded")
		} else if !strings.Contains(err.Error(), "no such file") {
			t.Fatalf("expected wrapped download error, got: %v", err)
		}
		if err := cmdDeploy(loaded, "deopjib", "dev", "deopjib-v1.0.0"); err != nil {
			t.Fatalf("no-op deploy after failed download failed: %v", err)
		}
		if readFile(t, stubLog) != before {
			t.Fatalf("failed download broke no-op detection on running target")
		}
	})

	t.Run("migration_failure_leaves_current_tags_untouched", func(t *testing.T) {
		previousBackend := readFile(t, filepath.Join(stubState, "backend"))
		previousWeb := readFile(t, filepath.Join(stubState, "web"))
		logBefore := readFile(t, stubLog)
		t.Setenv("STUB_FAIL_MIGRATION", "1")
		if err := cmdDeploy(loaded, "deopjib", "dev", "deopjib-v1.0.1"); err == nil {
			t.Fatalf("migration failure unexpectedly succeeded")
		}
		t.Setenv("STUB_FAIL_MIGRATION", "0")
		summary := readSummary(t, latest)
		if summary.Result != "migration-failed" {
			t.Fatalf("expected migration-failed, got %q", summary.Result)
		}
		newLog := strings.TrimPrefix(readFile(t, stubLog), logBefore)
		if strings.Contains(newLog, "podman tag ") {
			t.Fatalf("podman tag ran despite migration failure:\n%s", newLog)
		}
		if readFile(t, filepath.Join(stubState, "backend")) != previousBackend ||
			readFile(t, filepath.Join(stubState, "web")) != previousWeb {
			t.Fatalf("current tags changed after migration failure")
		}
	})
}

func TestRestoreFirstDeployKeepsOtherChannelTag(t *testing.T) {
	binDir := t.TempDir()
	names := filepath.Join(t.TempDir(), "names")
	stub := `#!/bin/sh
case "$1" in
  untag)
    if [ $# -eq 2 ]; then : > "$NAMES"; exit 0; fi
    shift 2
    for name in "$@"; do grep -vxF "$name" "$NAMES" > "$NAMES.new"; mv "$NAMES.new" "$NAMES"; done
    ;;
  image) grep -qxF "$3" "$NAMES" && echo shared-id ;;
  *) exit 1 ;;
esac
`
	if err := os.WriteFile(filepath.Join(binDir, "podman"), []byte(stub), 0o755); err != nil {
		t.Fatal(err)
	}
	devRef := "ghcr.io/example/app-backend:dev-current"
	prodRef := "ghcr.io/example/app-backend:prod-current"
	if err := os.WriteFile(names, []byte(devRef+"\n"+prodRef+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", binDir+":"+os.Getenv("PATH"))
	t.Setenv("NAMES", names)

	desired := []DesiredImage{{Service: "backend", ImageRef: prodRef}}
	before := []imageSnapshot{{Name: "backend", ImageRef: prodRef}}
	if !restoreReleaseImages(desired, before) {
		t.Fatalf("restore reported failure")
	}
	if got := readFile(t, names); got != devRef+"\n" {
		t.Fatalf("expected only %s to remain, got %q", devRef, got)
	}
}

func TestPruneKeepsOtherChannelImage(t *testing.T) {
	binDir := t.TempDir()
	removed := filepath.Join(t.TempDir(), "removed")
	stub := `#!/bin/sh
case "$1" in
  images) printf '%s\n' 'new prod-current' 'u1 <none>' 'u2 <none>' 'u3 <none>' 'dev-old dev-current' 'u4 <none>' ;;
  rmi) echo "$2" >> "$REMOVED" ;;
  *) exit 1 ;;
esac
`
	if err := os.WriteFile(filepath.Join(binDir, "podman"), []byte(stub), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", binDir+":"+os.Getenv("PATH"))
	t.Setenv("HOMELAB_APPCTL_STATE_ROOT", t.TempDir())
	t.Setenv("REMOVED", removed)

	pruneUntaggedImages([]string{"ghcr.io/example/app-backend"})

	if got := readFile(t, removed); got != "u4\n" {
		t.Fatalf("expected only u4 removed, got %q", got)
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
	newest := fmt.Sprintf("20260828T%06dZ.aaaaaa", keepDeployRecords+2)
	if _, err := os.Stat(filepath.Join(dir, newest)); err != nil {
		t.Fatalf("newest record was pruned")
	}
}

func TestCmdSmokeDoesNotFollowRedirects(t *testing.T) {
	redirected := false
	external := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		redirected = true
		w.WriteHeader(http.StatusOK)
	}))
	defer external.Close()

	loopback := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Host != "app.example.test" {
			w.WriteHeader(http.StatusBadRequest)
			return
		}
		http.Redirect(w, r, external.URL+"/escaped", http.StatusFound)
	}))
	defer loopback.Close()

	meta := &Metadata{
		Domain:     "app.example.test",
		CaddyURL:   loopback.URL,
		SmokePaths: []string{"/"},
	}
	if err := cmdSmoke(meta); err != nil {
		t.Fatalf("cmdSmoke rejected 302 loopback redirect: %v", err)
	}
	if redirected {
		t.Fatalf("cmdSmoke followed redirect off loopback")
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
