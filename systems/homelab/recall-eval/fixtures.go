package main

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

const exampleSentinel = "[EXAMPLE ONLY — replace with real memory UUID]"

type Fixture struct {
	ID                string   `yaml:"id"`
	Query             string   `yaml:"query"`
	ExpectedMemoryIDs []string `yaml:"expected_memory_ids"`
	Description       string   `yaml:"description"`
	Tags              []string `yaml:"tags"`
}

type FixtureSet struct {
	Version  int       `yaml:"version"`
	Bank     string    `yaml:"bank"`
	Fixtures []Fixture `yaml:"fixtures"`

	// Hash of the source bytes; set by LoadFixtures.
	VersionHash string `yaml:"-"`
}

func LoadFixtures(path string) (*FixtureSet, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read fixtures: %w", err)
	}

	var set FixtureSet
	if err := yaml.Unmarshal(data, &set); err != nil {
		return nil, fmt.Errorf("parse fixtures: %w", err)
	}

	if err := validateFixtures(&set); err != nil {
		return nil, err
	}

	sum := sha256.Sum256(data)
	set.VersionHash = hex.EncodeToString(sum[:])
	return &set, nil
}

func validateFixtures(set *FixtureSet) error {
	if set.Version != 1 {
		return fmt.Errorf("unsupported fixtures version %d (expect 1)", set.Version)
	}
	if set.Bank == "" {
		return errors.New("bank must be set")
	}
	if len(set.Fixtures) == 0 {
		return errors.New("no fixtures loaded")
	}

	seen := make(map[string]struct{}, len(set.Fixtures))
	for i, f := range set.Fixtures {
		if f.ID == "" {
			return fmt.Errorf("fixtures[%d]: id required", i)
		}
		if _, dup := seen[f.ID]; dup {
			return fmt.Errorf("duplicate fixture id %q", f.ID)
		}
		seen[f.ID] = struct{}{}

		if f.Query == "" {
			return fmt.Errorf("fixtures[%d] %s: query required", i, f.ID)
		}
		if len(f.ExpectedMemoryIDs) == 0 {
			return fmt.Errorf("fixtures[%d] %s: expected_memory_ids cannot be empty", i, f.ID)
		}
		for _, id := range f.ExpectedMemoryIDs {
			if id == exampleSentinel {
				return fmt.Errorf("fixtures[%d] %s: example sentinel detected — loaded example file by mistake", i, f.ID)
			}
		}
	}
	return nil
}
