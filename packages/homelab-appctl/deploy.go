package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"
)

const (
	keepDeployRecords = 10
	keepImageIDs      = 3
)

func runCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func commandOutput(name string, args ...string) (string, error) {
	var stdout bytes.Buffer
	cmd := exec.Command(name, args...)
	cmd.Stdout = &stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	return stdout.String(), err
}

func imageID(ref string) string {
	cmd := exec.Command("podman", "image", "inspect", ref, "--format", "{{.Id}}")
	var stdout bytes.Buffer
	cmd.Stdout = &stdout
	if err := cmd.Run(); err != nil {
		return ""
	}
	return strings.TrimSpace(stdout.String())
}

type imageSnapshot struct {
	Name     string `json:"name"`
	ImageRef string `json:"imageRef"`
	ImageID  string `json:"imageId"`
}

type deploySummary struct {
	App        string `json:"app"`
	Channel    string `json:"channel"`
	Target     string `json:"target"`
	DeployedAt string `json:"deployedAt"`
	Result     string `json:"result"`
	Images     struct {
		Before []imageSnapshot `json:"before"`
		After  []imageSnapshot `json:"after"`
	} `json:"images"`
	Migration struct {
		Result string `json:"result"`
	} `json:"migration"`
	Smoke struct {
		Result string `json:"result"`
	} `json:"smoke"`
}

func snapshotImages(meta *Metadata) []imageSnapshot {
	snapshots := make([]imageSnapshot, 0, len(meta.Services))
	for _, service := range meta.Services {
		snapshots = append(snapshots, imageSnapshot{
			Name:     service.Name,
			ImageRef: service.ImageRef,
			ImageID:  imageID(service.ImageRef),
		})
	}
	return snapshots
}

type deployRecord struct {
	dir  string
	path string
	meta *Metadata

	app, channel, target string
	migrationResult      string
	smokeResult          string
	before, after        []imageSnapshot
}

func (r *deployRecord) write(result string, updateLatest bool) error {
	var summary deploySummary
	summary.App = r.app
	summary.Channel = r.channel
	summary.Target = r.target
	summary.DeployedAt = time.Now().UTC().Format("2006-01-02T15:04:05Z")
	summary.Result = result
	summary.Images.Before = snapshotList(r.before)
	summary.Images.After = snapshotList(r.after)
	summary.Migration.Result = r.migrationResult
	summary.Smoke.Result = r.smokeResult

	data, err := json.MarshalIndent(summary, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(r.path, "summary.json"), append(data, '\n'), 0o644); err != nil {
		return err
	}
	if !updateLatest {
		return nil
	}
	latest := filepath.Join(r.dir, "latest")
	tmp := latest + ".tmp"
	_ = os.Remove(tmp)
	if err := os.Symlink(r.path, tmp); err != nil {
		return err
	}
	return os.Rename(tmp, latest)
}

func snapshotList(snapshots []imageSnapshot) []imageSnapshot {
	if snapshots == nil {
		return []imageSnapshot{}
	}
	return snapshots
}

func currentTarget(recordDir string, meta *Metadata) string {
	latest := filepath.Join(recordDir, "latest")
	rawSummary, err := os.ReadFile(filepath.Join(latest, "summary.json"))
	if err != nil {
		return ""
	}
	var summary deploySummary
	if err := json.Unmarshal(rawSummary, &summary); err != nil || summary.Result != "ok" {
		return ""
	}
	recorded, err := os.ReadFile(filepath.Join(latest, "metadata.json"))
	if err != nil || !bytes.Equal(recorded, meta.raw) {
		return ""
	}
	return strings.TrimSpace(summary.Target)
}

func acquireLock(lockPath string) (*os.File, error) {
	lock, err := os.OpenFile(lockPath, os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, err
	}
	deadline := time.Now().Add(900 * time.Second)
	for {
		err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
		if err == nil {
			return lock, nil
		}
		if !errors.Is(err, syscall.EWOULDBLOCK) && !errors.Is(err, syscall.EAGAIN) && !errors.Is(err, syscall.EINTR) {
			lock.Close()
			return nil, err
		}
		if time.Now().After(deadline) {
			lock.Close()
			return nil, fmt.Errorf("timed out waiting for lock %s", lockPath)
		}
		time.Sleep(time.Second)
	}
}

func pullReleaseImages(desired []DesiredImage) error {
	for _, image := range desired {
		fmt.Printf("pull: %s@%s\n", image.ImageName, image.Digest)
		if err := runCommand("podman", "pull", image.ImageName+"@"+image.Digest); err != nil {
			return err
		}
	}
	return nil
}

func activateReleaseImages(desired []DesiredImage) error {
	for _, image := range desired {
		fmt.Printf("activate: %s -> %s\n", image.ImageRef, image.Digest)
		if err := runCommand("podman", "tag", image.ImageName+"@"+image.Digest, image.ImageRef); err != nil {
			return err
		}
	}
	return nil
}

func restoreReleaseImages(desired []DesiredImage, before []imageSnapshot) bool {
	ok := true
	previous := make(map[string]string, len(before))
	for _, snapshot := range before {
		previous[snapshot.ImageRef] = snapshot.ImageID
	}
	for _, image := range desired {
		if id := previous[image.ImageRef]; id != "" {
			if err := runCommand("podman", "tag", id, image.ImageRef); err != nil {
				fmt.Fprintf(os.Stderr, "failed to restore %s to %s\n", image.ImageRef, id)
				ok = false
			}
			continue
		}
		// 이름 없는 `podman untag <image>`는 이미지의 모든 이름을 지운다. 채널끼리 같은
		// digest를 공유하면 다른 채널의 -current 태그까지 사라지므로 이 채널 ref만 지운다.
		if err := exec.Command("podman", "untag", image.ImageRef, image.ImageRef).Run(); err != nil {
			if imageID(image.ImageRef) != "" {
				fmt.Fprintf(os.Stderr, "failed to remove newly activated tag %s\n", image.ImageRef)
				ok = false
			}
		}
	}
	return ok
}

func runMigrationByDigest(meta *Metadata, desired []DesiredImage) error {
	var migrateImage string
	for _, image := range desired {
		if image.Service == meta.Migration.Service {
			migrateImage = image.ImageName + "@" + image.Digest
			break
		}
	}
	if migrateImage == "" {
		return fmt.Errorf("migration service %q not found in desired images", meta.Migration.Service)
	}
	runDir := runtimeRoot()
	if err := os.MkdirAll(runDir, 0o750); err != nil {
		return err
	}
	imageFile := filepath.Join(runDir, meta.UnitPrefix+"-migrate.image")
	tmpFile := imageFile + ".tmp"
	if err := os.WriteFile(tmpFile, []byte(migrateImage+"\n"), 0o600); err != nil {
		return err
	}
	if err := os.Rename(tmpFile, imageFile); err != nil {
		_ = os.Remove(tmpFile)
		return err
	}
	defer os.Remove(imageFile)

	fmt.Printf("migrate: %s (%s)\n", meta.Migration.Unit, migrateImage)
	return runCommand("systemctl", "start", meta.Migration.Unit)
}

func pruneDeployRecords(recordDir string) {
	entries, err := os.ReadDir(recordDir)
	if err != nil {
		return
	}
	var records []string
	for _, entry := range entries {
		name := entry.Name()
		if entry.IsDir() && len(name) > 0 && name[0] >= '0' && name[0] <= '9' {
			records = append(records, name)
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(records)))
	if len(records) <= keepDeployRecords {
		return
	}
	for _, name := range records[keepDeployRecords:] {
		_ = os.RemoveAll(filepath.Join(recordDir, name))
	}
}

func pruneUntaggedImages(imageRepos []string) {
	lockPath := filepath.Join(stateRoot(), "image-prune.lock")
	if err := os.MkdirAll(filepath.Dir(lockPath), 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "image prune skipped: cannot create lock dir: %v\n", err)
		return
	}
	lock, err := acquireLock(lockPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "image prune skipped: %v\n", err)
		return
	}
	defer lock.Close()
	seenRepos := map[string]bool{}
	for _, repo := range imageRepos {
		if seenRepos[repo] {
			continue
		}
		seenRepos[repo] = true
		output, err := commandOutput("podman", "images", "--sort", "created", repo, "--format", "{{.ID}} {{.Tag}}")
		if err != nil {
			continue
		}
		var ids []string
		seen := map[string]bool{}
		taggedImageIDs := map[string]bool{}
		for _, line := range strings.Split(output, "\n") {
			fields := strings.Fields(line)
			if len(fields) != 2 {
				continue
			}
			id := fields[0]
			if fields[1] != "<none>" {
				taggedImageIDs[id] = true
			}
			if !seen[id] {
				seen[id] = true
				ids = append(ids, id)
			}
		}
		kept := 0
		for _, id := range ids {
			if taggedImageIDs[id] {
				continue
			}
			if kept < keepImageIDs {
				kept++
				continue
			}
			fmt.Printf("prune image: %s %s\n", repo, id)
			if err := exec.Command("podman", "rmi", id).Run(); err != nil {
				fmt.Fprintf(os.Stderr, "image prune skipped (in use?): %s\n", id)
			}
		}
	}
}

func cmdDeployDryRun(meta *Metadata, app, channel, target string) error {
	if err := validateTargetPattern(meta, target); err != nil {
		return err
	}
	metaPath := filepath.Join(metadataRoot(), app, channel+".json")
	recordDir := filepath.Join(stateRoot(), app, channel)
	releaseManifestURL, err := manifestURL(meta, target)
	if err != nil {
		return err
	}

	fmt.Printf("metadata: %s\n", metaPath)
	fmt.Printf("target: %s\n", target)
	if current := currentTarget(recordDir, meta); current == target {
		fmt.Println("action: no-op; target already deployed")
	} else if current != "" {
		fmt.Printf("action: deploy; current target: %s\n", current)
	} else {
		fmt.Println("action: deploy; current target: none")
	}
	fmt.Printf("release manifest: %s\n", releaseManifestURL)

	tmpDir, err := os.MkdirTemp("", "appctl-dry-run.")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmpDir)
	manifestPath := filepath.Join(tmpDir, "release-manifest.json")
	if err := downloadManifest(releaseManifestURL, manifestPath); err != nil {
		return fmt.Errorf("release manifest download failed (%s): %w", releaseManifestURL, err)
	}
	manifest, err := loadManifest(manifestPath)
	if err != nil {
		return err
	}
	if err := validateManifest(meta, manifest, target); err != nil {
		return fmt.Errorf("release manifest does not match admitted metadata: %w", err)
	}
	desired, err := desiredImages(meta, manifest)
	if err != nil {
		return err
	}

	fmt.Println("release images:")
	for _, image := range desired {
		fmt.Printf("  %s@%s -> %s\n", image.ImageName, image.Digest, image.ImageRef)
	}
	if meta.Migration.Unit != "" {
		fmt.Println("migration unit:")
		fmt.Printf("  %s\n", meta.Migration.Unit)
	} else {
		fmt.Println("migration unit: none")
	}
	fmt.Println("release service units:")
	for _, service := range meta.releaseServices() {
		fmt.Printf("  %s\n", service.ServiceUnit)
	}
	fmt.Println("smoke paths:")
	for _, path := range meta.SmokePaths {
		fmt.Printf("  %s\n", path)
	}
	return nil
}

func cmdDeploy(meta *Metadata, app, channel, target string) error {
	if os.Geteuid() != 0 && !testModeActive() {
		return fmt.Errorf("deploy requires root because it writes %s and controls system services; run: sudo -n homelab-appctl deploy %s %s --target %s", stateRoot(), app, channel, target)
	}
	if err := validateTargetPattern(meta, target); err != nil {
		return err
	}

	recordDir := filepath.Join(stateRoot(), app, channel)
	if err := os.MkdirAll(recordDir, 0o755); err != nil {
		return err
	}
	lock, err := acquireLock(filepath.Join(recordDir, "deploy.lock"))
	if err != nil {
		return fmt.Errorf("%w: %s/%s", err, app, channel)
	}
	defer lock.Close()

	if current := currentTarget(recordDir, meta); current == target {
		fmt.Printf("target already deployed: %s\n", target)
		return nil
	}

	recordPath, err := os.MkdirTemp(recordDir, time.Now().UTC().Format("20060102T150405Z")+".")
	if err != nil {
		return err
	}
	if err := os.Chmod(recordPath, 0o755); err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(recordPath, "metadata.json"), meta.raw, 0o644); err != nil {
		return err
	}

	record := &deployRecord{
		dir:             recordDir,
		path:            recordPath,
		meta:            meta,
		app:             app,
		channel:         channel,
		target:          target,
		migrationResult: "skipped",
		smokeResult:     "not-run",
	}
	if meta.Migration.Unit != "" {
		record.migrationResult = "not-run"
	}

	releaseManifestURL, err := manifestURL(meta, target)
	if err != nil {
		_ = record.write("manifest-invalid", false)
		return err
	}
	fmt.Printf("manifest: %s\n", releaseManifestURL)
	manifestPath := filepath.Join(recordPath, "release-manifest.json")
	if err := downloadManifest(releaseManifestURL, manifestPath); err != nil {
		_ = record.write("manifest-download-failed", false)
		return fmt.Errorf("release manifest download failed (%s): %w", releaseManifestURL, err)
	}
	manifest, err := loadManifest(manifestPath)
	if err != nil {
		_ = record.write("manifest-invalid", false)
		return err
	}
	if err := validateManifest(meta, manifest, target); err != nil {
		_ = record.write("manifest-invalid", false)
		return fmt.Errorf("release manifest does not match admitted metadata: %w", err)
	}
	desired, err := desiredImages(meta, manifest)
	if err != nil {
		_ = record.write("manifest-invalid", false)
		return err
	}

	record.before = snapshotImages(meta)

	if err := pullReleaseImages(desired); err != nil {
		_ = record.write("pull-failed", false)
		return err
	}

	if err := record.write("in-progress", true); err != nil {
		return err
	}

	if meta.Migration.Unit != "" {
		if err := runMigrationByDigest(meta, desired); err != nil {
			record.migrationResult = "failed"
			_ = record.write("migration-failed", true)
			return err
		}
		record.migrationResult = "ok"
	}

	if err := activateReleaseImages(desired); err != nil {
		if restoreReleaseImages(desired, record.before) {
			_ = record.write("activation-failed", true)
		} else {
			_ = record.write("activation-recovery-failed", true)
		}
		return err
	}

	releaseUnits := meta.serviceUnits()
	fmt.Printf("restart: %s\n", strings.Join(releaseUnits, " "))
	if err := runCommand("systemctl", append([]string{"restart"}, releaseUnits...)...); err != nil {
		_ = record.write("restart-failed", true)
		return err
	}

	record.after = snapshotImages(meta)

	if err := cmdSmoke(meta); err != nil {
		record.smokeResult = "failed"
		_ = record.write("smoke-failed", true)
		fmt.Fprintf(os.Stderr, "smoke failed; deploy a known-good release target to roll back: %s\n", recordPath)
		return err
	}
	record.smokeResult = "ok"
	if err := record.write("ok", true); err != nil {
		return err
	}
	fmt.Printf("deploy record: %s\n", recordPath)

	pruneDeployRecords(recordDir)
	repos := make([]string, 0, len(desired))
	for _, image := range desired {
		repos = append(repos, image.ImageName)
	}
	pruneUntaggedImages(repos)
	return nil
}
