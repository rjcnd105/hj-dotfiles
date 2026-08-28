package main

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"time"
)

func cmdList() error {
	root := metadataRoot()
	entries, err := os.ReadDir(root)
	if err != nil {
		return nil
	}
	var paths []string
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		files, err := os.ReadDir(filepath.Join(root, entry.Name()))
		if err != nil {
			continue
		}
		for _, file := range files {
			if filepath.Ext(file.Name()) == ".json" {
				paths = append(paths, filepath.Join(root, entry.Name(), file.Name()))
			}
		}
	}
	sort.Strings(paths)
	for _, path := range paths {
		app := filepath.Base(filepath.Dir(path))
		channel := filepath.Base(path[:len(path)-len(".json")])
		meta, err := loadMetadata(app, channel)
		if err != nil {
			continue
		}
		fmt.Printf("%s\t%s\t%s\t%s\n", meta.Name, meta.Channel, meta.Domain, meta.UnitPrefix)
	}
	return nil
}

func cmdStatus(meta *Metadata) error {
	units := meta.serviceUnits()
	if len(units) == 0 {
		return fmt.Errorf("metadata has no service units")
	}
	return runCommand("systemctl", append([]string{"--no-pager", "status"}, units...)...)
}

func cmdLogs(meta *Metadata) error {
	units := meta.serviceUnits()
	if len(units) == 0 {
		return fmt.Errorf("metadata has no service units")
	}
	args := []string{"--no-pager", "-n", "200"}
	for _, unit := range units {
		args = append(args, "-u", unit)
	}
	return runCommand("journalctl", args...)
}

func cmdSmoke(meta *Metadata) error {
	if len(meta.SmokePaths) == 0 {
		return fmt.Errorf("metadata has no smoke paths")
	}
	client := &http.Client{Timeout: 5 * time.Second}
	const maxAttempts = 12
	for _, path := range meta.SmokePaths {
		fmt.Printf("smoke: %s %s\n", meta.Domain, path)
		var lastErr error
		for attempt := 1; attempt <= maxAttempts; attempt++ {
			if attempt > 1 {
				fmt.Fprintf(os.Stderr, "smoke retry: %s %s attempt %d/%d\n", meta.Domain, path, attempt, maxAttempts)
				time.Sleep(2 * time.Second)
			}
			req, err := http.NewRequest(http.MethodGet, meta.CaddyURL+path, nil)
			if err != nil {
				return err
			}
			req.Host = meta.Domain
			resp, err := client.Do(req)
			if err != nil {
				lastErr = err
				continue
			}
			resp.Body.Close()
			if resp.StatusCode >= 200 && resp.StatusCode < 400 {
				lastErr = nil
				break
			}
			lastErr = fmt.Errorf("GET %s%s: %s", meta.Domain, path, resp.Status)
		}
		if lastErr != nil {
			return lastErr
		}
	}
	return nil
}
