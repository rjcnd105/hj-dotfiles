package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"html"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
)

const schemaVersion = "1.0.0"

var idPattern = regexp.MustCompile(`^[a-z0-9]+(?:-[a-z0-9]+)*$`)
var galleryAnchorHrefPattern = regexp.MustCompile(`(?is)<a\b[^>]*\bhref\s*=\s*(?:"([^"]*)"|'([^']*)')`)

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
var supportSourceKinds = set("docs", "support-doc")
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
	"code_kernel_path",
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
	ingestSources := v.validateSourceRows(ingestRows, "ingest")
	v.validateSourceRows(seedRows, "source-seeds")
	v.validateSourceDetails(ingestSources)
	indexRows := v.readJSONL(filepath.Join(root, "references", "index.jsonl"))
	v.validateCatalog(indexRows, ingestSources)
	v.validateExampleDigests(indexRows)
	v.validateCodeKernels(indexRows)
	v.validateExampleGallery(indexRows)
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

func (v *validator) validateSourceRows(rows []row, label string) map[string]row {
	seen := map[string]row{}
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
		if _, ok := seen[eventID]; ok {
			v.errorf("%s: duplicate source_event_id", itemLabel)
		}
		seen[eventID] = item
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

func (v *validator) validateSourceDetails(sourceEvents map[string]row) {
	path := filepath.Join(v.root, "references", "source-details.md")
	content, err := os.ReadFile(path)
	if err != nil {
		v.errorf("missing source details file: %s", v.rel(path))
		return
	}
	sections := v.markdownSections(path, string(content))
	for eventID := range sourceEvents {
		if _, ok := sections[eventID]; !ok {
			v.errorf("source-details: missing heading for %s", eventID)
		}
	}
	for eventID := range sections {
		if _, ok := sourceEvents[eventID]; !ok {
			v.errorf("source-details: orphan heading for %s", eventID)
		}
	}
}

func (v *validator) validateCatalog(rows []row, sourceEvents map[string]row) {
	seenIDs := map[string]bool{}
	catalogIDs := map[string]bool{}
	aliases := map[string]string{}
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
		v.validateBrowserslistQuery(support, status, itemLabel)

		v.validateSourceRefs(item, sourceEvents, itemLabel)
		v.validateFiles(item, patternID, itemLabel)
		v.validateLists(item, itemLabel)
		v.validateAliases(item, patternID, aliases, itemLabel)

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

func (v *validator) validateExampleDigests(catalogRows []row) {
	path := filepath.Join(v.root, "references", "example-digests.md")
	content, err := os.ReadFile(path)
	if err != nil {
		v.errorf("missing example digests file: %s", v.rel(path))
		return
	}
	sections := v.markdownSections(path, string(content))
	catalogIDs := map[string]bool{}
	for _, item := range catalogRows {
		patternID := stringValue(item["id"])
		if patternID == "" {
			continue
		}
		catalogIDs[patternID] = true
		lines, ok := sections[patternID]
		if !ok {
			v.errorf("example-digests: missing heading for %s", patternID)
			continue
		}
		v.validateDigestSection(patternID, lines)
	}
	for patternID := range sections {
		if !catalogIDs[patternID] {
			v.errorf("example-digests: orphan heading for %s", patternID)
		}
	}
}

func (v *validator) validateCodeKernels(catalogRows []row) {
	legacyPath := filepath.Join(v.root, "references", "code-kernels.md")
	if fileExists(legacyPath) {
		v.errorf("code-kernels: legacy aggregate file must not exist: %s", v.rel(legacyPath))
	}

	dir := filepath.Join(v.root, "references", "code-kernels")
	entries, err := os.ReadDir(dir)
	if err != nil {
		v.errorf("missing code kernels directory: %s", v.rel(dir))
		return
	}

	expectedPaths := map[string]string{}
	for _, item := range catalogRows {
		patternID := stringValue(item["id"])
		if patternID == "" {
			continue
		}
		expectedPath := filepath.ToSlash(filepath.Join("references", "code-kernels", patternID+".md"))
		actualPath := stringValue(item["code_kernel_path"])
		itemLabel := "index:" + patternID
		if actualPath != expectedPath {
			v.errorf("%s: code_kernel_path must be %s", itemLabel, expectedPath)
			continue
		}
		expectedPaths[actualPath] = patternID

		fullPath := filepath.Join(v.root, actualPath)
		content, err := os.ReadFile(fullPath)
		if err != nil {
			v.errorf("%s: missing code kernel file %s", itemLabel, actualPath)
			continue
		}
		v.validateCodeKernelFile(patternID, actualPath, string(content))
	}

	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".md" {
			continue
		}
		relPath := filepath.ToSlash(filepath.Join("references", "code-kernels", entry.Name()))
		if _, ok := expectedPaths[relPath]; !ok {
			v.errorf("code-kernels: orphan file %s", relPath)
		}
	}
}

func (v *validator) validateCodeKernelFile(patternID, relPath, content string) {
	lines := strings.Split(content, "\n")
	nonEmpty := compactLines(lines)
	if len(nonEmpty) == 0 {
		v.errorf("%s: code kernel must not be empty", relPath)
		return
	}
	if len(nonEmpty) > 80 {
		v.errorf("%s: code kernel must stay token-light; got %d non-empty lines, max 80", relPath, len(nonEmpty))
	}
	if nonEmpty[0] != "# "+patternID {
		v.errorf("%s: first heading must be %q", relPath, "# "+patternID)
	}
	fences := 0
	for _, line := range nonEmpty {
		if strings.HasPrefix(line, "```") {
			fences++
		}
	}
	if fences < 2 {
		v.errorf("%s: code kernel must include a fenced code block", relPath)
	}
}

func (v *validator) validateExampleGallery(catalogRows []row) {
	path := filepath.Join(v.root, "examples", "index.html")
	content, err := os.ReadFile(path)
	if err != nil {
		v.errorf("missing example gallery file: %s", v.rel(path))
		return
	}

	text := string(content)
	galleryLinks := map[string]bool{}
	for _, match := range galleryAnchorHrefPattern.FindAllStringSubmatch(text, -1) {
		href := match[1]
		if href == "" {
			href = match[2]
		}
		galleryLinks[html.UnescapeString(href)] = true
	}

	expectedLinks := map[string]bool{}
	for _, item := range catalogRows {
		patternID := stringValue(item["id"])
		if patternID == "" {
			continue
		}
		href := "./" + patternID + "/index.html"
		expectedLinks[href] = true
		if !galleryLinks[href] {
			v.errorf("examples/index.html: missing gallery link for %s", patternID)
		}
	}
	for href := range galleryLinks {
		if strings.HasPrefix(href, "./") && strings.HasSuffix(href, "/index.html") &&
			!expectedLinks[href] {
			v.errorf("examples/index.html: orphan gallery link %s", href)
		}
	}
}

func (v *validator) validateDigestSection(patternID string, lines []string) {
	nonEmpty := compactLines(lines)
	if len(nonEmpty) == 0 {
		v.errorf("example-digests:%s: section must not be empty", patternID)
		return
	}
	if len(nonEmpty) > 7 {
		v.errorf("example-digests:%s: section must stay token-light; got %d non-empty lines, max 7", patternID, len(nonEmpty))
	}
	required := []string{
		"- Shows:",
		"- Best for:",
		"- Read full HTML when:",
	}
	for _, prefix := range required {
		if !hasLinePrefix(nonEmpty, prefix) {
			v.errorf("example-digests:%s: missing %q line", patternID, prefix)
		}
	}
	if !hasLinePrefix(nonEmpty, "- Key CSS:") && !hasLinePrefix(nonEmpty, "- Key CSS/HTML:") {
		v.errorf("example-digests:%s: missing key CSS/HTML line", patternID)
	}
	if hasLinePrefix(nonEmpty, "- Code kernel:") {
		v.errorf("example-digests:%s: do not duplicate code_kernel_path in digest", patternID)
	}
}

func (v *validator) validateSourceRefs(item row, sourceEvents map[string]row, itemLabel string) {
	refs := listValue(item["source_refs"])
	if len(refs) == 0 {
		v.errorf("%s: source_refs must be a non-empty list", itemLabel)
	}
	for _, ref := range refs {
		source, ok := sourceEvents[ref]
		if !ok {
			v.errorf("%s: source_ref %q not found in ingest log", itemLabel, ref)
			continue
		}
		if accepted, ok := source["accepted"].(bool); !ok || !accepted {
			v.errorf("%s: source_ref %q must point to accepted source event", itemLabel, ref)
		}
	}
	supportRef := stringValue(item["support_source_ref"])
	supportSource, ok := sourceEvents[supportRef]
	if !ok {
		v.errorf("%s: support_source_ref %q not found in ingest log", itemLabel, supportRef)
	} else {
		v.validateSupportSource(supportRef, supportSource, itemLabel)
	}

	exampleRef := stringValue(item["example_source_ref"])
	exampleSource, ok := sourceEvents[exampleRef]
	if !ok {
		v.errorf("%s: example_source_ref %q not found in ingest log", itemLabel, exampleRef)
	} else if accepted, ok := exampleSource["accepted"].(bool); !ok || !accepted {
		v.errorf("%s: example_source_ref %q must point to accepted source event", itemLabel, exampleRef)
	}
}

func (v *validator) validateSupportSource(ref string, source row, itemLabel string) {
	if accepted, ok := source["accepted"].(bool); !ok || !accepted {
		v.errorf("%s: support_source_ref %q must point to accepted source event", itemLabel, ref)
	}
	if status := stringValue(source["access_status"]); status != "accessible" {
		v.errorf("%s: support_source_ref %q must be accessible, got %q", itemLabel, ref, status)
	}
	if kind := stringValue(source["source_kind"]); !supportSourceKinds[kind] {
		v.errorf("%s: support_source_ref %q must be docs or support-doc, got %q", itemLabel, ref, kind)
	}
}

func (v *validator) validateBrowserslistQuery(support row, status string, itemLabel string) {
	query, isString := support["browserslist_query"].(string)
	if status == "baseline" {
		if !isString || strings.TrimSpace(query) == "" {
			v.errorf("%s: baseline support requires non-empty browserslist_query", itemLabel)
		}
		return
	}
	if support["browserslist_query"] != nil {
		v.errorf("%s: non-baseline support must use browserslist_query null", itemLabel)
	}
}

func (v *validator) validateFiles(item row, patternID string, itemLabel string) {
	examplePath := stringValue(item["example_path"])
	expectedExamplePath := filepath.ToSlash(filepath.Join("examples", patternID, "index.html"))
	if examplePath != expectedExamplePath {
		v.errorf("%s: example_path must be %s", itemLabel, expectedExamplePath)
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

func (v *validator) validateAliases(item row, patternID string, aliases map[string]string, itemLabel string) {
	for _, alias := range listValue(item["aliases"]) {
		normalized := strings.ToLower(strings.TrimSpace(alias))
		if normalized == "" {
			v.errorf("%s: aliases must not contain empty values", itemLabel)
			continue
		}
		if existing, ok := aliases[normalized]; ok && existing != patternID {
			v.errorf("%s: alias %q already used by %s", itemLabel, alias, existing)
			continue
		}
		aliases[normalized] = patternID
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

func (v *validator) markdownSections(path string, content string) map[string][]string {
	sections := map[string][]string{}
	current := ""
	scanner := bufio.NewScanner(strings.NewReader(content))
	lineNo := 0
	for scanner.Scan() {
		lineNo++
		line := scanner.Text()
		if strings.HasPrefix(line, "## ") {
			heading := strings.TrimSpace(strings.TrimPrefix(line, "## "))
			if !idPattern.MatchString(heading) {
				v.errorf("%s:%d: heading must be a source or pattern id, got %q", v.rel(path), lineNo, heading)
				current = ""
				continue
			}
			if _, exists := sections[heading]; exists {
				v.errorf("%s:%d: duplicate heading for %s", v.rel(path), lineNo, heading)
			}
			current = heading
			sections[current] = nil
			continue
		}
		if current != "" {
			sections[current] = append(sections[current], line)
		}
	}
	if err := scanner.Err(); err != nil {
		v.errorf("%s: read error: %v", v.rel(path), err)
	}
	return sections
}

func compactLines(lines []string) []string {
	result := make([]string, 0, len(lines))
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" {
			result = append(result, line)
		}
	}
	return result
}

func hasLinePrefix(lines []string, prefix string) bool {
	for _, line := range lines {
		if strings.HasPrefix(line, prefix) {
			return true
		}
	}
	return false
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
