package main

import (
	"strings"
	"testing"
)

const (
	hexA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	hexB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
)

func v2Metadata() *Metadata {
	return &Metadata{
		Name:            "deopjib",
		Channel:         "dev",
		UnitPrefix:      "deopjib-dev",
		Domain:          "dev.deopjib.site",
		CaddyURL:        "http://127.0.0.1:18099",
		ContractVersion: 2,
		SmokePaths:      []string{"/health"},
		Services: []ServiceMeta{
			{Name: "backend", ImageKey: "backend", ImageRef: "ghcr.io/x/backend:dev-current", ImageName: "ghcr.io/x/backend", ServiceUnit: "deopjib-dev-backend.service"},
			{Name: "web", ImageKey: "web", ImageRef: "ghcr.io/x/web:dev-current", ImageName: "ghcr.io/x/web", ServiceUnit: "deopjib-dev-web.service"},
		},
		Release: &ReleaseMeta{
			ManifestURL:   "https://example.test/{target}/release.json",
			Tag:           "dev-current",
			TargetPattern: `^deopjib-v.*$`,
		},
	}
}

func v2Manifest(target string) *Manifest {
	return &Manifest{
		SchemaVersion: 2,
		App:           "deopjib",
		Target:        target,
		Images: map[string]ManifestImage{
			"backend": {Name: "ghcr.io/x/backend", Digest: "sha256:" + hexA},
			"web":     {Name: "ghcr.io/x/web", Digest: "sha256:" + hexB},
		},
	}
}

func TestValidateManifestV2(t *testing.T) {
	meta := v2Metadata()
	target := "deopjib-v1.0.0"
	if err := validateManifest(meta, v2Manifest(target), target); err != nil {
		t.Fatalf("valid v2 manifest rejected: %v", err)
	}

	reject := func(label string, mutate func(*Manifest)) {
		manifest := v2Manifest(target)
		mutate(manifest)
		if err := validateManifest(meta, manifest, target); err == nil {
			t.Errorf("invalid manifest accepted: %s", label)
		}
	}
	reject("schema-version-1", func(m *Manifest) { m.SchemaVersion = 1 })
	reject("app", func(m *Manifest) { m.App = "other" })
	reject("target", func(m *Manifest) { m.Target = "deopjib-v9.9.9" })

	badTarget := "other-v1.0.0"
	if err := validateManifest(meta, v2Manifest(badTarget), badTarget); err == nil {
		t.Errorf("target outside admitted pattern accepted")
	}
}

func TestDesiredImages(t *testing.T) {
	meta := v2Metadata()
	manifest := v2Manifest("deopjib-v1.0.0")

	desired, err := desiredImages(meta, manifest)
	if err != nil {
		t.Fatalf("desiredImages: %v", err)
	}
	if len(desired) != 2 {
		t.Fatalf("expected 2 release images, got %d", len(desired))
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
	meta := v2Metadata()
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
