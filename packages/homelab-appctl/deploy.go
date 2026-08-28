package main

import (
	"bytes"
	"encoding/json"
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

// imageID returns the local image id for a reference, or "" when absent.
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

func writeSnapshotTSV(path string, snapshots []imageSnapshot) error {
	var builder strings.Builder
	for _, snapshot := range snapshots {
		fmt.Fprintf(&builder, "%s\t%s\t%s\n", snapshot.Name, snapshot.ImageRef, snapshot.ImageID)
	}
	return os.WriteFile(path, []byte(builder.String()), 0o644)
}

func writeDesiredTSV(path string, desired []DesiredImage) error {
	var builder strings.Builder
	for _, image := range desired {
		fmt.Fprintf(&builder, "%s\t%s\t%s\t%s\n", image.Service, image.ImageRef, image.ImageName, image.Digest)
	}
	return os.WriteFile(path, []byte(builder.String()), 0o644)
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

func (r *deployRecord) write(result string) {
	summary := map[string]any{
		"app":        r.app,
		"channel":    r.channel,
		"target":     r.target,
		"deployedAt": time.Now().UTC().Format("2006-01-02T15:04:05Z"),
		"result":     result,
		"images": map[string]any{
			"before": snapshotList(r.before),
			"after":  snapshotList(r.after),
		},
		"migration": map[string]any{"result": r.migrationResult},
		"smoke":     map[string]any{"result": r.smokeResult},
	}
	if r.target == "" {
		summary["target"] = nil
	}
	data, err := json.MarshalIndent(summary, "", "  ")
	if err == nil {
		os.WriteFile(filepath.Join(r.path, "summary.json"), append(data, '\n'), 0o644)
	}
	os.WriteFile(filepath.Join(r.path, "result"), []byte(result+"\n"), 0o644)

	latest := filepath.Join(r.dir, "latest")
	tmp := latest + ".tmp"
	os.Remove(tmp)
	if err := os.Symlink(r.path, tmp); err == nil {
		os.Rename(tmp, latest)
	}
}

func snapshotList(snapshots []imageSnapshot) []imageSnapshot {
	if snapshots == nil {
		return []imageSnapshot{}
	}
	return snapshots
}

// currentTarget returns the target of the latest successful deploy whose
// admitted metadata is byte-identical to the current metadata.
func currentTarget(recordDir string, meta *Metadata) string {
	latest := filepath.Join(recordDir, "latest")
	result, err := os.ReadFile(filepath.Join(latest, "result"))
	if err != nil || strings.TrimSpace(string(result)) != "ok" {
		return ""
	}
	target, err := os.ReadFile(filepath.Join(latest, "target"))
	if err != nil {
		return ""
	}
	recorded, err := os.ReadFile(filepath.Join(latest, "metadata.json"))
	if err != nil || !bytes.Equal(recorded, meta.raw) {
		return ""
	}
	return strings.TrimSpace(string(target))
}

func acquireDeployLock(recordDir string) (*os.File, error) {
	lock, err := os.OpenFile(filepath.Join(recordDir, "deploy.lock"), os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return nil, err
	}
	deadline := time.Now().Add(900 * time.Second)
	for {
		err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
		if err == nil {
			return lock, nil
		}
		if time.Now().After(deadline) {
			lock.Close()
			return nil, fmt.Errorf("timed out waiting for deploy lock")
		}
		time.Sleep(time.Second)
	}
}

func pullReleaseImages(meta *Metadata, desired []DesiredImage) error {
	var authArgs []string
	if meta.RegistryAuthFile != "" {
		authArgs = []string{"--authfile", meta.RegistryAuthFile}
	}
	for _, image := range desired {
		fmt.Printf("pull: %s@%s\n", image.ImageName, image.Digest)
		args := append([]string{"pull"}, authArgs...)
		args = append(args, image.ImageName+"@"+image.Digest)
		if err := runCommand("podman", args...); err != nil {
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
		if err := exec.Command("podman", "untag", image.ImageRef).Run(); err != nil {
			if imageID(image.ImageRef) != "" {
				fmt.Fprintf(os.Stderr, "failed to remove newly activated tag %s\n", image.ImageRef)
				ok = false
			}
		}
	}
	return ok
}

// pruneDeployRecords keeps the newest keepDeployRecords record directories.
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
		os.RemoveAll(filepath.Join(recordDir, name))
	}
}

// pruneReleaseImages keeps the newest keepImageIDs image ids per release image
// name, never removing ids the current references point at.
func pruneReleaseImages(meta *Metadata, desired []DesiredImage) {
	protected := map[string]bool{}
	for _, service := range meta.Services {
		if id := imageID(service.ImageRef); id != "" {
			protected[id] = true
		}
	}
	for _, image := range desired {
		if id := imageID(image.ImageName + "@" + image.Digest); id != "" {
			protected[id] = true
		}
	}

	names := map[string]bool{}
	for _, image := range desired {
		names[image.ImageName] = true
	}
	for name := range names {
		output, err := commandOutput("podman", "images", name, "--format", "{{.ID}}")
		if err != nil {
			continue
		}
		var ids []string
		seen := map[string]bool{}
		for _, id := range strings.Fields(output) {
			if !seen[id] {
				seen[id] = true
				ids = append(ids, id)
			}
		}
		kept := 0
		for _, id := range ids {
			if protected[id] {
				continue
			}
			if kept < keepImageIDs {
				kept++
				continue
			}
			fmt.Printf("prune image: %s %s\n", name, id)
			if err := exec.Command("podman", "rmi", id).Run(); err != nil {
				fmt.Fprintf(os.Stderr, "image prune skipped (in use?): %s\n", id)
			}
		}
	}
}

func cmdDeployDryRun(meta *Metadata, app, channel, target string) error {
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
		return fmt.Errorf("release manifest download failed: %s", releaseManifestURL)
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

	recordDir := filepath.Join(stateRoot(), app, channel)
	if err := os.MkdirAll(recordDir, 0o755); err != nil {
		return err
	}
	lock, err := acquireDeployLock(recordDir)
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
	shaOut, err := commandOutput("sha256sum", filepath.Join(recordPath, "metadata.json"))
	if err == nil {
		os.WriteFile(filepath.Join(recordPath, "metadata.sha256"), []byte(shaOut), 0o644)
	}
	os.WriteFile(filepath.Join(recordPath, "target"), []byte(target+"\n"), 0o644)

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
	record.before = snapshotImages(meta)
	writeSnapshotTSV(filepath.Join(recordPath, "before-images.tsv"), record.before)
	record.write("in-progress")

	releaseManifestURL, err := manifestURL(meta, target)
	if err != nil {
		record.write("manifest-invalid")
		return err
	}
	fmt.Printf("manifest: %s\n", releaseManifestURL)
	manifestPath := filepath.Join(recordPath, "release-manifest.json")
	if err := downloadManifest(releaseManifestURL, manifestPath); err != nil {
		record.write("manifest-download-failed")
		return fmt.Errorf("release manifest download failed: %s", releaseManifestURL)
	}
	manifest, err := loadManifest(manifestPath)
	if err != nil {
		record.write("manifest-invalid")
		return err
	}
	if err := validateManifest(meta, manifest, target); err != nil {
		record.write("manifest-invalid")
		return fmt.Errorf("release manifest does not match admitted metadata: %w", err)
	}
	desired, err := desiredImages(meta, manifest)
	if err != nil {
		record.write("manifest-invalid")
		return err
	}
	writeDesiredTSV(filepath.Join(recordPath, "desired-images.tsv"), desired)

	if err := pullReleaseImages(meta, desired); err != nil {
		record.write("pull-failed")
		return err
	}

	if err := activateReleaseImages(desired); err != nil {
		if restoreReleaseImages(desired, record.before) {
			record.write("activation-failed")
		} else {
			record.write("activation-recovery-failed")
		}
		return err
	}

	if meta.Migration.Unit != "" {
		fmt.Printf("migrate: %s\n", meta.Migration.Unit)
		if err := runCommand("systemctl", "start", meta.Migration.Unit); err != nil {
			record.migrationResult = "failed"
			if restoreReleaseImages(desired, record.before) {
				record.write("migration-failed")
			} else {
				record.write("migration-recovery-failed")
			}
			return err
		}
		record.migrationResult = "ok"
	}

	releaseUnits := []string{}
	for _, service := range meta.releaseServices() {
		releaseUnits = append(releaseUnits, service.ServiceUnit)
	}
	if len(releaseUnits) == 0 {
		record.write("manifest-invalid")
		return fmt.Errorf("metadata has no release service units")
	}
	fmt.Printf("restart: %s\n", strings.Join(releaseUnits, " "))
	if err := runCommand("systemctl", append([]string{"restart"}, releaseUnits...)...); err != nil {
		record.write("restart-failed")
		return err
	}

	record.after = snapshotImages(meta)
	writeSnapshotTSV(filepath.Join(recordPath, "after-images.tsv"), record.after)

	if err := cmdSmoke(meta); err != nil {
		record.smokeResult = "failed"
		record.write("smoke-failed")
		fmt.Fprintf(os.Stderr, "smoke failed; deploy a known-good release target to roll back: %s\n", recordPath)
		return err
	}
	record.smokeResult = "ok"
	record.write("ok")
	fmt.Printf("deploy record: %s\n", recordPath)

	pruneDeployRecords(recordDir)
	pruneReleaseImages(meta, desired)
	return nil
}
