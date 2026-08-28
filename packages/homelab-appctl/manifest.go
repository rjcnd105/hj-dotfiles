package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"time"
)

// Manifest is the app-published release manifest.
// schemaVersion 1 carries the four deployment source hashes; schemaVersion 2
// is digest-only: {schemaVersion, app, target, images{key: {name, digest}}}.
type Manifest struct {
	SchemaVersion      int    `json:"schemaVersion"`
	App                string `json:"app"`
	Target             string `json:"target"`
	SourceRev          string `json:"sourceRev"`
	DeploymentContract struct {
		RuntimeSourceSha256   string `json:"runtimeSourceSha256"`
		AdmissionSourceSha256 string `json:"admissionSourceSha256"`
		SchemaSourceSha256    string `json:"schemaSourceSha256"`
		GeneratorSourceSha256 string `json:"generatorSourceSha256"`
	} `json:"deploymentContract"`
	Images map[string]ManifestImage `json:"images"`
}

type ManifestImage struct {
	Name   string `json:"name"`
	Digest string `json:"digest"`
}

// DesiredImage is one release-managed image resolved against the manifest.
type DesiredImage struct {
	Service   string
	ImageRef  string
	ImageName string
	Digest    string
}

var (
	digestPattern    = regexp.MustCompile(`^sha256:[0-9a-f]{64}$`)
	sourceRevPattern = regexp.MustCompile(`^[0-9a-f]{40}$`)
)

func manifestURL(meta *Metadata, target string) (string, error) {
	if meta.Release == nil || meta.Release.ManifestURL == "" {
		return "", errors.New("metadata has no release manifest URL")
	}
	template := meta.Release.ManifestURL
	if !strings.Contains(template, "{target}") {
		return "", fmt.Errorf("release manifest URL is missing {target}: %s", template)
	}
	return strings.ReplaceAll(template, "{target}", target), nil
}

func validateManifest(meta *Metadata, manifest *Manifest, target string) error {
	if meta.Release == nil {
		return errors.New("metadata has no release section")
	}
	pattern, err := regexp.Compile(meta.Release.TargetPattern)
	if err != nil {
		return fmt.Errorf("invalid admitted target pattern: %w", err)
	}
	if manifest.App != meta.Name {
		return fmt.Errorf("manifest app %q does not match admitted app %q", manifest.App, meta.Name)
	}
	if manifest.Target != target {
		return fmt.Errorf("manifest target %q does not match requested target %q", manifest.Target, target)
	}
	if !pattern.MatchString(target) {
		return fmt.Errorf("target %q does not match admitted pattern %s", target, meta.Release.TargetPattern)
	}

	if meta.ContractVersion == 2 {
		if manifest.SchemaVersion != 2 {
			return fmt.Errorf("contract v2 requires manifest schemaVersion 2, got %d", manifest.SchemaVersion)
		}
		return nil
	}

	if manifest.SchemaVersion != 1 {
		return fmt.Errorf("contract v1 requires manifest schemaVersion 1, got %d", manifest.SchemaVersion)
	}
	if !sourceRevPattern.MatchString(manifest.SourceRev) {
		return fmt.Errorf("manifest sourceRev must be a 40-hex commit id")
	}
	contract := manifest.DeploymentContract
	hashPairs := []struct{ manifest, admitted, label string }{
		{contract.RuntimeSourceSha256, meta.RuntimeContractSourceSha256, "runtimeSourceSha256"},
		{contract.AdmissionSourceSha256, meta.HomelabAdmissionSourceSha256, "admissionSourceSha256"},
		{contract.SchemaSourceSha256, meta.ManifestSchemaSourceSha256, "schemaSourceSha256"},
		{contract.GeneratorSourceSha256, meta.ManifestGeneratorSourceSha256, "generatorSourceSha256"},
	}
	for _, pair := range hashPairs {
		if pair.manifest == "" || pair.manifest != pair.admitted {
			return fmt.Errorf("manifest %s does not match admitted metadata", pair.label)
		}
	}
	return nil
}

func desiredImages(meta *Metadata, manifest *Manifest) ([]DesiredImage, error) {
	var desired []DesiredImage
	for _, service := range meta.releaseServices() {
		image, ok := manifest.Images[service.ImageKey]
		if !ok || image.Name == "" || image.Digest == "" {
			return nil, fmt.Errorf("manifest is missing image %s for service %s", service.ImageKey, service.Name)
		}
		if image.Name != service.ImageName {
			return nil, fmt.Errorf("manifest image name mismatch for %s: %s", service.Name, image.Name)
		}
		if !digestPattern.MatchString(image.Digest) {
			return nil, fmt.Errorf("invalid manifest digest for %s: %s", service.Name, image.Digest)
		}
		desired = append(desired, DesiredImage{
			Service:   service.Name,
			ImageRef:  service.ImageRef,
			ImageName: image.Name,
			Digest:    image.Digest,
		})
	}
	if len(desired) == 0 {
		return nil, errors.New("release manifest has no valid admitted images")
	}
	return desired, nil
}

func httpsOnlyClient(timeout time.Duration) *http.Client {
	return &http.Client{
		Timeout: timeout,
		CheckRedirect: func(req *http.Request, _ []*http.Request) error {
			if req.URL.Scheme != "https" {
				return fmt.Errorf("insecure redirect to %s", req.URL)
			}
			return nil
		},
	}
}

func githubTokenFile() string {
	return os.Getenv("HOMELAB_APPCTL_GITHUB_TOKEN_FILE")
}

// testModeActive gates test-only behavior (file:// manifests, non-root deploy)
// to non-root runs whose metadata and state roots are both overridden.
func testModeActive() bool {
	return os.Getenv("HOMELAB_APPCTL_TEST_ALLOW_FILE_URL") == "1" &&
		os.Geteuid() != 0 &&
		metadataRoot() != "/etc/homelab-apps" &&
		stateRoot() != "/var/lib/homelab-appctl"
}

// downloadManifest fetches a release manifest. HTTPS only; file:// is allowed
// only for non-root test runs with overridden roots. GitHub release-download
// URLs resolve through the REST API when a token is configured, because the
// browser download path rejects fine-grained PATs.
func downloadManifest(rawURL, output string) error {
	switch {
	case strings.HasPrefix(rawURL, "https://github.com/") && strings.Contains(rawURL, "/releases/download/"):
		tokenFile := githubTokenFile()
		if tokenFile != "" {
			if _, err := os.Stat(tokenFile); err == nil {
				return githubReleaseAsset(rawURL, output, tokenFile)
			}
		}
		return fetchToFile(rawURL, output, nil)
	case strings.HasPrefix(rawURL, "https://"):
		return fetchToFile(rawURL, output, nil)
	case strings.HasPrefix(rawURL, "file://"):
		if testModeActive() {
			data, err := os.ReadFile(strings.TrimPrefix(rawURL, "file://"))
			if err != nil {
				return err
			}
			return os.WriteFile(output, data, 0o644)
		}
		return fmt.Errorf("release manifest URL must use HTTPS: %s", rawURL)
	default:
		return fmt.Errorf("release manifest URL must use HTTPS: %s", rawURL)
	}
}

func fetchToFile(rawURL, output string, header http.Header) error {
	client := httpsOnlyClient(30 * time.Second)
	req, err := http.NewRequest(http.MethodGet, rawURL, nil)
	if err != nil {
		return err
	}
	for key, values := range header {
		for _, value := range values {
			req.Header.Add(key, value)
		}
	}
	var lastErr error
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			time.Sleep(time.Duration(attempt) * time.Second)
		}
		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		if resp.StatusCode != http.StatusOK {
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
			lastErr = fmt.Errorf("GET %s: %s", rawURL, resp.Status)
			continue
		}
		data, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			lastErr = err
			continue
		}
		return os.WriteFile(output, data, 0o644)
	}
	return lastErr
}

func githubReleaseAsset(rawURL, output, tokenFile string) error {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return err
	}
	// /OWNER/REPO/releases/download/TAG.../NAME — the tag may contain slashes.
	parts := strings.Split(strings.TrimPrefix(parsed.Path, "/"), "/")
	if len(parts) < 5 || parts[2] != "releases" || parts[3] != "download" {
		return fmt.Errorf("malformed GitHub release URL: %s", rawURL)
	}
	owner, repo := parts[0], parts[1]
	name := parts[len(parts)-1]
	tag := strings.Join(parts[4:len(parts)-1], "/")
	if owner == "" || repo == "" || tag == "" || name == "" {
		return fmt.Errorf("malformed GitHub release URL: %s", rawURL)
	}

	token, err := os.ReadFile(tokenFile)
	if err != nil {
		return err
	}
	auth := http.Header{
		"Authorization": []string{"Bearer " + strings.TrimSpace(string(token))},
	}

	api := fmt.Sprintf("https://api.github.com/repos/%s/%s", owner, repo)
	client := httpsOnlyClient(30 * time.Second)
	req, err := http.NewRequest(http.MethodGet, api+"/releases/tags/"+tag, nil)
	if err != nil {
		return err
	}
	req.Header = auth.Clone()
	req.Header.Set("Accept", "application/vnd.github+json")
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("GET %s: %s", req.URL, resp.Status)
	}
	var release struct {
		Assets []struct {
			ID   int64  `json:"id"`
			Name string `json:"name"`
		} `json:"assets"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return err
	}
	var assetID int64
	for _, asset := range release.Assets {
		if asset.Name == name {
			assetID = asset.ID
			break
		}
	}
	if assetID == 0 {
		return fmt.Errorf("release asset not found: %s in %s", name, tag)
	}

	assetHeader := auth.Clone()
	assetHeader.Set("Accept", "application/octet-stream")
	return fetchToFile(fmt.Sprintf("%s/releases/assets/%d", api, assetID), output, assetHeader)
}

func loadManifest(path string) (*Manifest, error) {
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var manifest Manifest
	if err := json.Unmarshal(raw, &manifest); err != nil {
		return nil, fmt.Errorf("invalid release manifest: %w", err)
	}
	return &manifest, nil
}
