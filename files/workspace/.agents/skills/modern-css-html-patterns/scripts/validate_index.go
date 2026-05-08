package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
)

const schemaVersion = "1.0.0"

var idPattern = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)

var categories = set(
	"layout",
	"interaction",
	"motion",
	"state-query",
	"visual-effect",
	"typography",
	"form-control",
	"html-primitive",
)

var sourceKinds = set("inspiration", "article", "docs", "code", "demo", "support-doc")
var accessStatuses = set("accessible", "blocked", "partial", "not-checked")
var verificationStatuses = set(
	"extracted",
	"reconstructed",
	"verified",
	"needs-review",
	"limited-fallback-only",
)
var supportStatuses = set("baseline", "limited", "experimental", "deprecated")

var catalogRequired = set(
	"schema_version",
	"id",
	"title",
	"category",
	"aliases",
	"css_features",
	"html_features",
	"source_refs",
	"support_source_ref",
	"example_source_ref",
	"verification_status",
	"support",
	"fallback",
	"fallback_test_method",
	"verification_mode",
	"example_path",
	"states_demonstrated",
	"checked_states",
	"checked_viewports",
	"a11y_checks",
	"verification_evidence",
	"example_verified_at",
	"verification_target",
	"expected_primary_result",
	"fallback_result",
	"related_patterns",
	"last_checked",
)

var supportRequired = set(
	"status",
	"baseline_target",
	"browserslist_query",
	"query_verified",
	"requires",
	"caveats",
)

var sourceRequired = set(
	"schema_version",
	"source_event_id",
	"source_id",
	"url",
	"source_kind",
	"access_status",
	"http_status",
	"checked_at",
	"captured_evidence",
	"intended_pattern_ids",
	"accepted",
	"rejected_reason",
)

type row map[string]any

type validator struct {
	root   string
	errors []string
}

func main() {
	root, err := discoverRoot()
	if err != nil {
		fmt.Fprintln(os.Stderr, "ERROR:", err)
		os.Exit(1)
	}

	v := &validator{root: root}
	ingestRows := v.readJSONL(filepath.Join(root, "logs", "ingest.jsonl"))
	seedRows := v.readJSONL(filepath.Join(root, "references", "source-seeds.jsonl"))
	ingestIDs := v.validateSourceRows(ingestRows, "ingest")
	v.validateSourceRows(seedRows, "source-seeds")
	v.validateSourceDetails(ingestIDs)
	indexRows := v.readJSONL(filepath.Join(root, "references", "index.jsonl"))
	v.validateCatalog(indexRows, ingestIDs)
	v.validateBacklog()

	if len(v.errors) > 0 {
		for _, msg := range v.errors {
			fmt.Fprintln(os.Stderr, "ERROR:", msg)
		}
		os.Exit(1)
	}
	fmt.Printf("Validated %d patterns and %d source events.\n", len(indexRows), len(ingestRows))
}

func discoverRoot() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	candidates := []string{
		cwd,
		filepath.Join(cwd, "files", "workspace", ".agents", "skills", "modern-css-html-patterns"),
	}
	_, sourceFile, _, ok := runtime.Caller(0)
	if ok {
		candidates = append(candidates, filepath.Dir(filepath.Dir(sourceFile)))
	}
	for _, candidate := range candidates {
		if fileExists(filepath.Join(candidate, "references", "index.jsonl")) &&
			fileExists(filepath.Join(candidate, "logs", "ingest.jsonl")) {
			return candidate, nil
		}
	}
	return "", fmt.Errorf("could not find modern-css-html-patterns skill root from %s", cwd)
}

func (v *validator) readJSONL(path string) []row {
	file, err := os.Open(path)
	if err != nil {
		v.errorf("missing file: %s", v.rel(path))
		return nil
	}
	defer file.Close()

	var rows []row
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	lineNo := 0
	for scanner.Scan() {
		lineNo++
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var value row
		if err := json.Unmarshal([]byte(line), &value); err != nil {
			v.errorf("%s:%d: invalid JSON: %v", v.rel(path), lineNo, err)
			continue
		}
		rows = append(rows, value)
	}
	if err := scanner.Err(); err != nil {
		v.errorf("%s: read error: %v", v.rel(path), err)
	}
	return rows
}

func (v *validator) validateSourceRows(rows []row, label string) map[string]bool {
	seen := map[string]bool{}
	for _, item := range rows {
		eventID := stringValue(item["source_event_id"])
		if eventID == "" {
			eventID = "<missing>"
		}
		itemLabel := label + ":" + eventID
		v.requireFields(item, sourceRequired, itemLabel)
		if stringValue(item["schema_version"]) != schemaVersion {
			v.errorf("%s: schema_version must be %s", itemLabel, schemaVersion)
		}
		if seen[eventID] {
			v.errorf("%s: duplicate source_event_id", itemLabel)
		}
		seen[eventID] = true
		if !sourceKinds[stringValue(item["source_kind"])] {
			v.errorf("%s: invalid source_kind %q", itemLabel, item["source_kind"])
		}
		if !accessStatuses[stringValue(item["access_status"])] {
			v.errorf("%s: invalid access_status %q", itemLabel, item["access_status"])
		}
		if _, ok := item["intended_pattern_ids"].([]any); !ok {
			v.errorf("%s: intended_pattern_ids must be a list", itemLabel)
		}
		if _, ok := item["accepted"].(bool); !ok {
			v.errorf("%s: accepted must be boolean", itemLabel)
		}
	}
	return seen
}

func (v *validator) validateSourceDetails(sourceEventIDs map[string]bool) {
	path := filepath.Join(v.root, "references", "source-details.md")
	content, err := os.ReadFile(path)
	if err != nil {
		v.errorf("missing source details file: %s", v.rel(path))
		return
	}
	text := string(content)
	for eventID := range sourceEventIDs {
		if !strings.Contains(text, "## "+eventID+"\n") {
			v.errorf("source-details: missing heading for %s", eventID)
		}
	}
}

func (v *validator) validateCatalog(rows []row, sourceEventIDs map[string]bool) {
	seenIDs := map[string]bool{}
	catalogIDs := map[string]bool{}
	for _, item := range rows {
		catalogIDs[stringValue(item["id"])] = true
	}

	for _, item := range rows {
		patternID := stringValue(item["id"])
		if patternID == "" {
			patternID = "<missing>"
		}
		itemLabel := "index:" + patternID
		v.requireFields(item, catalogRequired, itemLabel)
		if stringValue(item["schema_version"]) != schemaVersion {
			v.errorf("%s: schema_version must be %s", itemLabel, schemaVersion)
		}
		if !idPattern.MatchString(patternID) {
			v.errorf("%s: id must be kebab-case", itemLabel)
		}
		if seenIDs[patternID] {
			v.errorf("%s: duplicate id", itemLabel)
		}
		seenIDs[patternID] = true
		if !categories[stringValue(item["category"])] {
			v.errorf("%s: invalid category %q", itemLabel, item["category"])
		}
		if !verificationStatuses[stringValue(item["verification_status"])] {
			v.errorf("%s: invalid verification_status %q", itemLabel, item["verification_status"])
		}

		support, ok := item["support"].(map[string]any)
		if !ok {
			v.errorf("%s: support must be an object", itemLabel)
			continue
		}
		v.requireFields(support, supportRequired, itemLabel+".support")
		status := stringValue(support["status"])
		if !supportStatuses[status] {
			v.errorf("%s: invalid support.status %q", itemLabel, support["status"])
		}
		if _, ok := support["query_verified"].(bool); !ok {
			v.errorf("%s: support.query_verified must be boolean", itemLabel)
		}

		v.validateSourceRefs(item, sourceEventIDs, itemLabel)
		v.validateFiles(item, patternID, itemLabel)
		v.validateLists(item, itemLabel)

		if status == "limited" || status == "experimental" ||
			stringValue(item["verification_status"]) == "limited-fallback-only" {
			if stringValue(item["fallback"]) == "" || stringValue(item["fallback_test_method"]) == "" {
				v.errorf("%s: limited features require fallback details", itemLabel)
			}
			if stringValue(item["fallback_result"]) == "" {
				v.errorf("%s: limited features require fallback_result", itemLabel)
			}
		}

		isInteractive := stringValue(item["category"]) == "interaction" ||
			stringValue(item["category"]) == "html-primitive"
		hasHTMLPrimitive := len(listValue(item["html_features"])) > 0
		if isInteractive || hasHTMLPrimitive {
			if len(listValue(item["checked_states"])) == 0 {
				v.errorf("%s: interactive patterns require checked_states", itemLabel)
			}
			if len(listValue(item["a11y_checks"])) == 0 {
				v.errorf("%s: interactive patterns require a11y_checks", itemLabel)
			}
		}

		for _, related := range listValue(item["related_patterns"]) {
			if !catalogIDs[related] {
				v.errorf("%s: unknown related pattern %q", itemLabel, related)
			}
		}
	}
}

func (v *validator) validateSourceRefs(item row, sourceEventIDs map[string]bool, itemLabel string) {
	refs := listValue(item["source_refs"])
	if len(refs) == 0 {
		v.errorf("%s: source_refs must be a non-empty list", itemLabel)
	}
	for _, ref := range refs {
		if !sourceEventIDs[ref] {
			v.errorf("%s: source_ref %q not found in ingest log", itemLabel, ref)
		}
	}
	for _, field := range []string{"support_source_ref", "example_source_ref"} {
		ref := stringValue(item[field])
		if !sourceEventIDs[ref] {
			v.errorf("%s: %s %q not found in ingest log", itemLabel, field, ref)
		}
	}
}

func (v *validator) validateFiles(item row, patternID string, itemLabel string) {
	examplePath := stringValue(item["example_path"])
	if !strings.HasSuffix(examplePath, "/index.html") {
		v.errorf("%s: example_path must end with /index.html", itemLabel)
		return
	}
	if !fileExists(filepath.Join(v.root, examplePath)) {
		v.errorf("%s: missing example file %s", itemLabel, examplePath)
	}

	patternPath := filepath.Join(v.root, "references", "patterns", patternID+".md")
	if !fileExists(patternPath) {
		v.errorf("%s: missing pattern doc references/patterns/%s.md", itemLabel, patternID)
		return
	}
	content, err := os.ReadFile(patternPath)
	if err != nil {
		v.errorf("%s: could not read pattern doc: %v", itemLabel, err)
		return
	}
	expected := "Catalog ID: `" + patternID + "`"
	if !strings.Contains(string(content), expected) {
		v.errorf("%s: pattern doc must include exact catalog ID", itemLabel)
	}
}

func (v *validator) validateLists(item row, itemLabel string) {
	for _, field := range []string{
		"aliases",
		"css_features",
		"html_features",
		"source_refs",
		"states_demonstrated",
		"checked_states",
		"checked_viewports",
		"a11y_checks",
		"related_patterns",
	} {
		if _, ok := item[field].([]any); !ok {
			v.errorf("%s: %s must be a list", itemLabel, field)
		}
	}
}

func (v *validator) validateBacklog() {
	rows := v.readJSONL(filepath.Join(v.root, "references", "backlog.jsonl"))
	seen := map[string]bool{}
	for _, item := range rows {
		itemID := stringValue(item["id"])
		if itemID == "" {
			itemID = "<missing>"
		}
		itemLabel := "backlog:" + itemID
		if seen[itemID] {
			v.errorf("%s: duplicate id", itemLabel)
		}
		seen[itemID] = true
		for _, field := range []string{"schema_version", "id", "source_refs", "reason", "next_step"} {
			if _, ok := item[field]; !ok {
				v.errorf("%s: missing %s", itemLabel, field)
			}
		}
		if stringValue(item["schema_version"]) != schemaVersion {
			v.errorf("%s: schema_version must be %s", itemLabel, schemaVersion)
		}
	}
}

func (v *validator) requireFields(item row, required map[string]bool, label string) {
	var missing []string
	for field := range required {
		if _, ok := item[field]; !ok {
			missing = append(missing, field)
		}
	}
	if len(missing) > 0 {
		sort.Strings(missing)
		v.errorf("%s: missing required fields: %s", label, strings.Join(missing, ", "))
	}
}

func (v *validator) errorf(format string, args ...any) {
	v.errors = append(v.errors, fmt.Sprintf(format, args...))
}

func (v *validator) rel(path string) string {
	rel, err := filepath.Rel(v.root, path)
	if err != nil {
		return path
	}
	return rel
}

func set(values ...string) map[string]bool {
	result := make(map[string]bool, len(values))
	for _, value := range values {
		result[value] = true
	}
	return result
}

func stringValue(value any) string {
	if value == nil {
		return ""
	}
	text, ok := value.(string)
	if !ok {
		return ""
	}
	return text
}

func listValue(value any) []string {
	values, ok := value.([]any)
	if !ok {
		return nil
	}
	result := make([]string, 0, len(values))
	for _, value := range values {
		text, ok := value.(string)
		if ok {
			result = append(result, text)
		}
	}
	return result
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}
