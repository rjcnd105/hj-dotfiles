package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
)

// Metadata mirrors /etc/homelab-apps/<app>/<channel>.json rendered by
// systems/homelab/app-containers.nix. contractVersion 0 (absent) means the
// schemaVersion 1 contract with the four deployment source hashes.
type Metadata struct {
	AppKey          string `json:"appKey"`
	Name            string `json:"name"`
	Channel         string `json:"channel"`
	UnitPrefix      string `json:"unitPrefix"`
	Domain          string `json:"domain"`
	CaddyURL        string `json:"caddyUrl"`
	ContractVersion int    `json:"contractVersion"`

	RuntimeContractSourceSha256  string `json:"runtimeContractSourceSha256"`
	HomelabAdmissionSourceSha256 string `json:"homelabAdmissionSourceSha256"`
	ManifestSchemaSourceSha256   string `json:"manifestSchemaSourceSha256"`
	ManifestGeneratorSourceSha256 string `json:"manifestGeneratorSourceSha256"`

	RegistryAuthFile string        `json:"registryAuthFile"`
	SmokePaths       []string      `json:"smokePaths"`
	Services         []ServiceMeta `json:"services"`
	Migration        MigrationMeta `json:"migration"`
	Release          *ReleaseMeta  `json:"release"`

	raw []byte
}

type ServiceMeta struct {
	Name           string   `json:"name"`
	ImageKey       string   `json:"imageKey"`
	ImageRef       string   `json:"imageRef"`
	ImageName      string   `json:"imageName"`
	ReleaseManaged bool     `json:"releaseManaged"`
	ServiceUnit    string   `json:"serviceUnit"`
	ContainerName  string   `json:"containerName"`
	HealthPath     string   `json:"healthPath"`
	DependsOn      []string `json:"dependsOn"`
	UpdatePolicy   string   `json:"updatePolicy"`
}

type MigrationMeta struct {
	Mode    string   `json:"mode"`
	Service string   `json:"service"`
	Unit    string   `json:"unit"`
	Command []string `json:"command"`
}

type ReleaseMeta struct {
	ManifestURL   string   `json:"manifestUrl"`
	Tag           string   `json:"tag"`
	Mode          string   `json:"mode"`
	TargetPattern string   `json:"targetPattern"`
	Strategy      string   `json:"strategy"`
	Migrate       string   `json:"migrate"`
	SmokePaths    []string `json:"smokePaths"`
}

var idPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9-]*$`)
var targetPattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]*$`)

func requireID(label, value string) error {
	if !idPattern.MatchString(value) {
		return fmt.Errorf("%s must match ^[a-z0-9][a-z0-9-]*$: %s", label, value)
	}
	return nil
}

func requireTarget(value string) error {
	if !targetPattern.MatchString(value) {
		return fmt.Errorf("target must match ^[A-Za-z0-9][A-Za-z0-9._-]*$: %s", value)
	}
	return nil
}

func metadataRoot() string {
	if v := os.Getenv("HOMELAB_APPCTL_METADATA_ROOT"); v != "" {
		return v
	}
	return "/etc/homelab-apps"
}

func stateRoot() string {
	if v := os.Getenv("HOMELAB_APPCTL_STATE_ROOT"); v != "" {
		return v
	}
	return "/var/lib/homelab-appctl"
}

func loadMetadata(app, channel string) (*Metadata, error) {
	if err := requireID("app", app); err != nil {
		return nil, err
	}
	if err := requireID("channel", channel); err != nil {
		return nil, err
	}
	path := filepath.Join(metadataRoot(), app, channel+".json")
	raw, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("missing metadata: %s", path)
	}
	var meta Metadata
	if err := json.Unmarshal(raw, &meta); err != nil {
		return nil, fmt.Errorf("invalid metadata %s: %w", path, err)
	}
	meta.raw = raw
	return &meta, nil
}

func (m *Metadata) serviceUnits() []string {
	units := make([]string, 0, len(m.Services))
	for _, service := range m.Services {
		units = append(units, service.ServiceUnit)
	}
	return units
}

func (m *Metadata) releaseServices() []ServiceMeta {
	var services []ServiceMeta
	for _, service := range m.Services {
		if service.ReleaseManaged {
			services = append(services, service)
		}
	}
	return services
}
