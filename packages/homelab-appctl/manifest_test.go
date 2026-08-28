package main

import (
	"strings"
	"testing"
)

const (
	hexA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	hexB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
	hexC = "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
	hexD = "dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd"
	rev  = "0123456789abcdef0123456789abcdef01234567"
)

func v1Metadata() *Metadata {
	return &Metadata{
		Name:                          "deopjib",
		Channel:                       "dev",
		RuntimeContractSourceSha256:   hexA,
		HomelabAdmissionSourceSha256:  hexB,
		ManifestSchemaSourceSha256:    hexC,
		ManifestGeneratorSourceSha256: hexD,
		Services: []ServiceMeta{
			{Name: "db", ImageKey: "db", ImageRef: "docker.io/library/postgres@sha256:" + hexA, UpdatePolicy: "pinned-digest"},
			{Name: "backend", ImageKey: "backend", ImageRef: "ghcr.io/x/backend:dev-current", ImageName: "ghcr.io/x/backend", ReleaseManaged: true, ServiceUnit: "deopjib-dev-backend.service", UpdatePolicy: "manual"},
			{Name: "web", ImageKey: "web", ImageRef: "ghcr.io/x/web:dev-current", ImageName: "ghcr.io/x/web", ReleaseManaged: true, ServiceUnit: "deopjib-dev-web.service", UpdatePolicy: "manual"},
		},
		Release: &ReleaseMeta{
			ManifestURL:   "https://example.test/{target}/release.json",
			TargetPattern: `^deopjib-v.*$`,
		},
	}
}

func v1Manifest(target string) *Manifest {
	manifest := &Manifest{
		SchemaVersion: 1,
		App:           "deopjib",
		Target:        target,
		SourceRev:     rev,
		Images: map[string]ManifestImage{
			"backend": {Name: "ghcr.io/x/backend", Digest: "sha256:" + hexA},
			"web":     {Name: "ghcr.io/x/web", Digest: "sha256:" + hexB},
		},
	}
	manifest.DeploymentContract.RuntimeSourceSha256 = hexA
	manifest.DeploymentContract.AdmissionSourceSha256 = hexB
	manifest.DeploymentContract.SchemaSourceSha256 = hexC
	manifest.DeploymentContract.GeneratorSourceSha256 = hexD
	return manifest
}

func TestValidateManifestV1(t *testing.T) {
	meta := v1Metadata()
	target := "deopjib-v1.0.0"
	if err := validateManifest(meta, v1Manifest(target), target); err != nil {
		t.Fatalf("valid v1 manifest rejected: %v", err)
	}

	reject := func(label string, mutate func(*Manifest)) {
		manifest := v1Manifest(target)
		mutate(manifest)
		if err := validateManifest(meta, manifest, target); err == nil {
			t.Errorf("invalid manifest accepted: %s", label)
		}
	}
	reject("schema-version", func(m *Manifest) { m.SchemaVersion = 2 })
	reject("app", func(m *Manifest) { m.App = "other" })
	reject("target", func(m *Manifest) { m.Target = "deopjib-v9.9.9" })
	reject("source-rev", func(m *Manifest) { m.SourceRev = "short" })
	reject("runtime-hash", func(m *Manifest) { m.DeploymentContract.RuntimeSourceSha256 = hexD })
	reject("admission-hash", func(m *Manifest) { m.DeploymentContract.AdmissionSourceSha256 = hexA })
	reject("schema-hash", func(m *Manifest) { m.DeploymentContract.SchemaSourceSha256 = hexA })
	reject("generator-hash", func(m *Manifest) { m.DeploymentContract.GeneratorSourceSha256 = hexA })

	badTarget := "other-v1.0.0"
	manifest := v1Manifest(badTarget)
	if err := validateManifest(meta, manifest, badTarget); err == nil {
		t.Errorf("target outside admitted pattern accepted")
	}
}

func TestValidateManifestV2DigestOnly(t *testing.T) {
	meta := v1Metadata()
	meta.ContractVersion = 2
	meta.RuntimeContractSourceSha256 = ""
	meta.HomelabAdmissionSourceSha256 = ""
	meta.ManifestSchemaSourceSha256 = ""
	meta.ManifestGeneratorSourceSha256 = ""

	target := "deopjib-v1.0.0"
	manifest := &Manifest{
		SchemaVersion: 2,
		App:           "deopjib",
		Target:        target,
		Images: map[string]ManifestImage{
			"backend": {Name: "ghcr.io/x/backend", Digest: "sha256:" + hexA},
			"web":     {Name: "ghcr.io/x/web", Digest: "sha256:" + hexB},
		},
	}
	if err := validateManifest(meta, manifest, target); err != nil {
		t.Fatalf("valid v2 manifest rejected: %v", err)
	}

	manifest.SchemaVersion = 1
	if err := validateManifest(meta, manifest, target); err == nil {
		t.Errorf("contract v2 accepted manifest schemaVersion 1")
	}
}

func TestDesiredImages(t *testing.T) {
	meta := v1Metadata()
	manifest := v1Manifest("deopjib-v1.0.0")

	desired, err := desiredImages(meta, manifest)
	if err != nil {
		t.Fatalf("desiredImages: %v", err)
	}
	if len(desired) != 2 {
		t.Fatalf("expected 2 release images, got %d", len(desired))
	}
	for _, image := range desired {
		if image.Service == "db" {
			t.Errorf("pinned database service leaked into release images")
		}
	}

	manifest.Images["backend"] = ManifestImage{Name: "ghcr.io/x/not-admitted", Digest: "sha256:" + hexA}
	if _, err := desiredImages(meta, manifest); err == nil {
		t.Errorf("image name mismatch accepted")
	}

	manifest.Images["backend"] = ManifestImage{Name: "ghcr.io/x/backend", Digest: "sha256:zzz"}
	if _, err := desiredImages(meta, manifest); err == nil {
		t.Errorf("malformed digest accepted")
	}
}

func TestManifestURL(t *testing.T) {
	meta := v1Metadata()
	url, err := manifestURL(meta, "deopjib-v1.0.0")
	if err != nil {
		t.Fatalf("manifestURL: %v", err)
	}
	if !strings.Contains(url, "/deopjib-v1.0.0/") {
		t.Errorf("target not substituted: %s", url)
	}

	meta.Release.ManifestURL = "https://example.test/static.json"
	if _, err := manifestURL(meta, "deopjib-v1.0.0"); err == nil {
		t.Errorf("manifest URL without {target} accepted")
	}
}
