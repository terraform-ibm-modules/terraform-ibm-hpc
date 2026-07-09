// Package tests provides utilities for parsing Go verbose test logs and
// generating HTML reports with grouped, hierarchical test results.
package tests

import (
	"bufio"
	"fmt"
	"html/template"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// ── Data types ────────────────────────────────────────────────────────────────

// TestResult holds the parsed result of a single test case.
type TestResult struct {
	Test    string  `json:"test"`
	Action  string  `json:"action"`
	Elapsed float64 `json:"elapsed"` // minutes
	Error   string  `json:"error"`
}

// SubTest is a leaf-level test row inside a Stage.
type SubTest struct {
	Name    string
	Status  string
	Elapsed float64
}

// Stage is a second-level test (e.g. "ValidateCluster") that may contain
// leaf SubTests (e.g. "CheckNodes", "CheckServices").
type Stage struct {
	Name     string
	Status   string
	Elapsed  float64
	Children []SubTest // third-level, may be empty
}

// ParentTest represents a top-level test together with its stages.
type ParentTest struct {
	Name      string
	Status    string
	Stages    []Stage
	TotalTime float64
	Errors    []string // deduplicated error messages for the Failure Details box
}

// ReportData contains all data needed to render the HTML report template.
type ReportData struct {
	TotalTests   int
	TotalPass    int
	TotalFail    int
	TotalTime    float64
	DateTime     string
	GroupedTests []ParentTest
}

// ── Parsing ───────────────────────────────────────────────────────────────────

// ParseJSONFile reads a verbose Go test log (plain text) and returns a flat
// slice of TestResults for every test seen.
//
// # Status truth rule
//
// ONLY "--- PASS: …" and "--- FAIL: …" lines written by the Go test runner
// set a test's final status. ERROR log lines collect the message text for
// display but never mutate status — the runner's verdict is the ground truth.
func ParseJSONFile(fileName string) ([]TestResult, error) {
	file, err := os.Open(fileName)
	if err != nil {
		return nil, fmt.Errorf("open log file %q: %w", fileName, err)
	}
	defer closeFile(file, fileName)

	reResult := regexp.MustCompile(`--- (PASS|FAIL): (\S+) \((\d+\.\d+)s\)`)
	reLog := regexp.MustCompile(`(INFO|ERROR|PASS)\s+\[\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\]\s+\[([^\]]+)\]\s+(.+)`)
	reRun := regexp.MustCompile(`=== (RUN|PAUSE|CONT)\s+(\S+)`)
	reANSI := regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]|\x1b\[[0-9;]*[mK]`)

	stripANSI := func(s string) string {
		return strings.TrimSpace(reANSI.ReplaceAllString(s, ""))
	}

	// testStatus written ONLY by "--- PASS|FAIL" lines.
	testStatus := make(map[string]string)
	// testErrors stores messages for display; never affects status.
	testErrors := make(map[string][]string)
	testElapsed := make(map[string]float64)
	// allTests preserves every test name seen, in insertion order.
	seen := make(map[string]bool)
	var allTests []string

	touch := func(name string) {
		if !seen[name] {
			seen[name] = true
			allTests = append(allTests, name)
		}
	}

	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)

	for scanner.Scan() {
		line := stripANSI(scanner.Text())
		switch {

		// "--- PASS|FAIL: TestName (1.23s)" — the only status source.
		case reResult.MatchString(line):
			m := reResult.FindStringSubmatch(line)
			name, status := m[2], m[1]
			secs, _ := strconv.ParseFloat(m[3], 64)
			testStatus[name] = status
			testElapsed[name] = secs / 60
			touch(name)

		// "INFO|ERROR|PASS [ts] [TestName] message" — errors for display only.
		case reLog.MatchString(line):
			m := reLog.FindStringSubmatch(line)
			level, name, msg := m[1], m[2], m[3]
			touch(name)
			if level == "ERROR" {
				testErrors[name] = append(testErrors[name], msg)
			}

		// "=== RUN|PAUSE|CONT TestName"
		case reRun.MatchString(line):
			touch(reRun.FindStringSubmatch(line)[2])
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("read log file %q: %w", fileName, err)
	}

	results := make([]TestResult, 0, len(allTests))
	for _, name := range allTests {
		status := testStatus[name]
		if status == "" {
			status = "UNKNOWN"
		}
		results = append(results, TestResult{
			Test:    name,
			Action:  status,
			Elapsed: testElapsed[name],
			Error:   strings.Join(testErrors[name], "; "),
		})
	}
	return results, nil
}

// ── Statistics ────────────────────────────────────────────────────────────────

// calculateStats counts only top-level tests (no "/" in name).
// Time is summed from top-level elapsed values only, preventing double-counting.
func calculateStats(results []TestResult) (totalTests, totalPass, totalFail int, totalTime float64) {
	seen := make(map[string]bool)
	for _, r := range results {
		if strings.Contains(r.Test, "/") {
			continue
		}
		if seen[r.Test] {
			continue
		}
		seen[r.Test] = true
		totalTests++
		totalTime += r.Elapsed
		switch r.Action {
		case "PASS":
			totalPass++
		case "FAIL":
			totalFail++
		}
	}
	return
}

// ── Grouping — 3-level hierarchy ─────────────────────────────────────────────
//
// Depth 0: ParentTest       e.g. TestRunSubTestFail
// Depth 1: Stage            e.g. TestRunSubTestFail/ValidateCluster
// Depth 2: SubTest (leaf)   e.g. TestRunSubTestFail/ValidateCluster/CheckNodes
//
// groupTests builds this from the flat []TestResult produced by ParseJSONFile.
// Parent status is taken directly from the runner's "--- PASS|FAIL" verdict and
// is never re-derived from child statuses — that was the source of fake results.

func groupTests(results []TestResult) []ParentTest {
	// Index results by full name for O(1) lookup.
	byName := make(map[string]TestResult, len(results))
	for _, r := range results {
		byName[r.Test] = r
	}

	parents := make(map[string]*ParentTest)
	stages := make(map[string]*Stage) // key: "ParentName/StageName"
	var parentOrder []string
	parentSeen := make(map[string]bool)

	ensureParent := func(name string) *ParentTest {
		if !parentSeen[name] {
			parentSeen[name] = true
			parentOrder = append(parentOrder, name)
			r := byName[name]
			status := r.Action
			if status == "" {
				status = "UNKNOWN"
			}
			parents[name] = &ParentTest{
				Name:      name,
				Status:    status,
				TotalTime: r.Elapsed,
			}
		}
		return parents[name]
	}

	ensureStage := func(parentName, stageName, fullName string) *Stage {
		key := parentName + "/" + stageName
		if _, ok := stages[key]; !ok {
			r := byName[fullName]
			status := r.Action
			if status == "" {
				status = "UNKNOWN"
			}
			p := ensureParent(parentName)
			p.Stages = append(p.Stages, Stage{
				Name:    stageName,
				Status:  status,
				Elapsed: r.Elapsed,
			})
			stages[key] = &p.Stages[len(p.Stages)-1]
		}
		return stages[key]
	}

	for _, r := range results {
		parts := strings.SplitN(r.Test, "/", 3)

		switch len(parts) {
		case 1:
			// Top-level test — ensureParent already captured status from byName.
			ensureParent(parts[0])

			// Bubble top-level error messages.
			if r.Error != "" {
				p := parents[parts[0]]
				p.Errors = append(p.Errors, r.Test+": "+r.Error)
			}

		case 2:
			// Depth-1: Parent/Stage
			parentName, stageName := parts[0], parts[1]
			ensureStage(parentName, stageName, r.Test)

			// Bubble stage error messages to parent.
			if r.Error != "" {
				p := ensureParent(parentName)
				p.Errors = append(p.Errors, r.Test+": "+r.Error)
			}

		case 3:
			// Depth-2: Parent/Stage/Leaf
			parentName, stageName, leafName := parts[0], parts[1], parts[2]
			st := ensureStage(parentName, stageName, parentName+"/"+stageName)

			status := r.Action
			if status == "" {
				status = "UNKNOWN"
			}
			st.Children = append(st.Children, SubTest{
				Name:    leafName,
				Status:  status,
				Elapsed: r.Elapsed,
			})

			// Bubble leaf error messages to parent.
			if r.Error != "" {
				p := ensureParent(parentName)
				p.Errors = append(p.Errors, r.Test+": "+r.Error)
			}
		}
	}

	// Deduplicate errors per parent.
	for _, p := range parents {
		p.Errors = deduplicateStrings(p.Errors)
	}

	list := make([]ParentTest, 0, len(parentOrder))
	for _, k := range parentOrder {
		list = append(list, *parents[k])
	}
	return list
}

// deduplicateStrings returns ss with duplicate entries removed (first-seen wins).
func deduplicateStrings(ss []string) []string {
	seen := make(map[string]bool, len(ss))
	out := ss[:0:0]
	for _, s := range ss {
		if !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	return out
}

// ── Report generation ─────────────────────────────────────────────────────────

// GenerateHTMLReport writes a self-contained HTML report to disk.
func GenerateHTMLReport(results []TestResult) error {
	if len(results) == 0 {
		return fmt.Errorf("no test results to report")
	}

	funcMap := template.FuncMap{
		"splitPath": func(s string) string {
			if idx := strings.Index(s, ": "); idx >= 0 {
				return s[:idx]
			}
			return s
		},
		"splitMsg": func(s string) string {
			if idx := strings.Index(s, ": "); idx >= 0 {
				return s[idx+2:]
			}
			return s
		},
	}

	tmpl, err := template.New("report").Funcs(funcMap).Parse(reportTemplate)
	if err != nil {
		return fmt.Errorf("parse report template: %w", err)
	}

	totalTests, totalPass, totalFail, totalTime := calculateStats(results)
	groupedTests := groupTests(results)

	data := ReportData{
		TotalTests:   totalTests,
		TotalPass:    totalPass,
		TotalFail:    totalFail,
		TotalTime:    totalTime,
		DateTime:     time.Now().Format("2006-01-02 15:04:05"),
		GroupedTests: groupedTests,
	}

	name := reportFileName()
	f, err := os.Create(name)
	if err != nil {
		return fmt.Errorf("create report file %q: %w", name, err)
	}
	defer closeFile(f, name)

	var sb strings.Builder
	if err := tmpl.Execute(&sb, data); err != nil {
		return fmt.Errorf("execute report template: %w", err)
	}
	if _, err := f.WriteString(sb.String()); err != nil {
		return fmt.Errorf("write report file: %w", err)
	}

	fmt.Printf("✅ HTML report generated: %s\n", name)
	return nil
}

// reportFileName derives the output filename from LOG_FILE_NAME env var,
// falling back to a timestamped default.
func reportFileName() string {
	if logFile, ok := os.LookupEnv("LOG_FILE_NAME"); ok && logFile != "" {
		return strings.TrimSuffix(logFile, ".json") + ".html"
	}
	return "test-report-" + time.Now().Format("20060102-150405") + ".html"
}

// closeFile closes f, printing a warning to stderr on failure.
func closeFile(f *os.File, name string) {
	if err := f.Close(); err != nil {
		fmt.Fprintf(os.Stderr, "warning: close %q: %v\n", name, err)
	}
}

// ── HTML template ─────────────────────────────────────────────────────────────

const reportTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HPC Test Report</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@300;400;600&display=swap" rel="stylesheet">
<style>
  :root{
    --bg:#0d0f14;--sur:#141820;--bdr:#1e2430;
    --txt:#c8d0e0;--dim:#5a6478;--hi:#eaf0ff;
    --pass:#00d97e;--pass-bg:#00d97e18;
    --fail:#ff4d6a;--fail-bg:#ff4d6a18;
    --unk:#f5a623;--unk-bg:#f5a62318;
    --acc:#3b82f6;
    --mono:'IBM Plex Mono',monospace;--sans:'IBM Plex Sans',sans-serif;
  }
  *,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
  body{font-family:var(--sans);background:var(--bg);color:var(--txt);padding-bottom:60px}

  /* ── Header ── */
  .hdr{background:var(--sur);border-bottom:1px solid var(--bdr);padding:22px 40px;display:flex;align-items:center;justify-content:space-between;position:sticky;top:0;z-index:100}
  .hdr-l{display:flex;align-items:center;gap:12px}
  .logo{width:34px;height:34px;background:var(--acc);border-radius:8px;display:grid;place-items:center}
  .logo svg{width:18px;height:18px;stroke:#fff;stroke-width:2;fill:none;stroke-linecap:round;stroke-linejoin:round}
  .htitle{font-family:var(--mono);font-size:14px;font-weight:600;color:var(--hi);letter-spacing:.04em}
  .hsub{font-family:var(--mono);font-size:10px;color:var(--dim);letter-spacing:.08em;text-transform:uppercase;margin-top:2px}
  .hmeta{font-family:var(--mono);font-size:11px;color:var(--dim);text-align:right}
  .hmeta span{display:block;color:var(--txt);font-size:12px;margin-top:2px}

  /* ── Page ── */
  .page{max-width:1100px;margin:0 auto;padding:32px 40px 0}

  /* ── Metric cards ── */
  .metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:32px}
  .mc{background:var(--sur);border:1px solid var(--bdr);border-radius:12px;padding:20px 22px;position:relative;overflow:hidden;animation:fu .4s ease both}
  .mc::after{content:'';position:absolute;bottom:0;left:0;right:0;height:2px}
  .mc-total::after{background:var(--acc)}.mc-pass::after{background:var(--pass)}.mc-fail::after{background:var(--fail)}.mc-time::after{background:#a78bfa}
  .ml{font-size:10px;font-family:var(--mono);text-transform:uppercase;letter-spacing:.1em;color:var(--dim);margin-bottom:8px}
  .mv{font-family:var(--mono);font-size:32px;font-weight:600;line-height:1}
  .mc-total .mv{color:var(--acc)}.mc-pass .mv{color:var(--pass)}.mc-fail .mv{color:var(--fail)}.mc-time .mv{color:#a78bfa;font-size:24px}

  /* ── Section header ── */
  .ph{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px}
  .ptitle{font-family:var(--mono);font-size:10px;text-transform:uppercase;letter-spacing:.1em;color:var(--dim)}
  .pcount{font-family:var(--mono);font-size:10px;color:var(--dim)}

  /* ── Group card ── */
  .gcard{background:var(--sur);border:1px solid var(--bdr);border-radius:12px;margin-bottom:14px;overflow:hidden;animation:fu .4s ease both}
  .gcard.fail-card{border-color:rgba(255,77,106,.35)}
  /* onclick only on header — body clicks never collapse the card */
  .ghdr{display:flex;align-items:center;justify-content:space-between;padding:15px 20px;cursor:pointer;user-select:none;transition:background .15s}
  .ghdr:hover{background:var(--bdr)}
  .ghdr-l{display:flex;align-items:center;gap:10px}
  .chev{width:15px;height:15px;transition:transform .25s;flex-shrink:0;stroke:var(--dim);fill:none;stroke-width:2.5;stroke-linecap:round;stroke-linejoin:round}
  .gcard.open .chev{transform:rotate(90deg)}
  .gname{font-family:var(--mono);font-size:13px;font-weight:600;color:var(--hi)}
  .gtime{font-family:var(--mono);font-size:11px;color:var(--dim)}
  .gbody{display:none;border-top:1px solid var(--bdr)}
  .gcard.open .gbody{display:block}

  /* ── Status pills ── */
  .pill{display:inline-flex;align-items:center;gap:5px;font-size:10px;font-weight:600;padding:2px 9px;border-radius:20px;font-family:var(--mono);letter-spacing:.04em}
  .pill::before{content:'';width:4px;height:4px;border-radius:50%}
  .pp{background:var(--pass-bg);color:var(--pass)}.pp::before{background:var(--pass)}
  .pf{background:var(--fail-bg);color:var(--fail)}.pf::before{background:var(--fail)}
  .pu{background:var(--unk-bg);color:var(--unk)}.pu::before{background:var(--unk)}

  /* ── Depth-1 stage rows ── */
  .srow{display:flex;align-items:center;padding:10px 20px 10px 48px;border-bottom:1px solid var(--bdr);background:transparent;transition:background .1s}
  .srow:hover{background:var(--bdr)}
  .srow.has-children{cursor:pointer}
  .srow-l{display:flex;align-items:center;gap:8px;flex:1;min-width:0}
  .schev{width:12px;height:12px;transition:transform .2s;flex-shrink:0;stroke:var(--dim);fill:none;stroke-width:2.5;stroke-linecap:round;stroke-linejoin:round;opacity:0}
  .srow.has-children .schev{opacity:1}
  .srow.open .schev{transform:rotate(90deg)}
  .sname{font-family:var(--mono);font-size:12px;color:var(--txt);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  .sstatus{flex:0 0 95px}
  .stime{font-family:var(--mono);font-size:11px;color:var(--dim);flex:0 0 100px}

  /* ── Depth-2 leaf rows ── */
  .children{display:none;border-bottom:1px solid var(--bdr)}
  .srow.open + .children{display:block}
  .lrow{display:flex;align-items:center;padding:8px 20px 8px 80px;border-bottom:1px solid rgba(30,36,48,.6);transition:background .1s}
  .lrow:last-child{border-bottom:none}
  .lrow:hover{background:var(--bdr)}
  .lname{font-family:var(--mono);font-size:11px;color:var(--dim);flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  .lstatus{flex:0 0 95px}
  .ltime{font-family:var(--mono);font-size:11px;color:var(--dim);flex:0 0 100px}

  /* ── Error box (hard failures) ── */
  .ebox-wrap{padding:16px 20px}
  .ebox{border:1px solid var(--fail);border-left:3px solid var(--fail);border-radius:6px;padding:12px 16px;background:var(--fail-bg)}
  .ebox-lbl{font-family:var(--mono);font-size:9px;text-transform:uppercase;letter-spacing:.12em;color:var(--fail);opacity:.6;margin-bottom:8px}
  .error-item{padding:8px 0;border-bottom:1px solid rgba(255,77,106,.25)}
  .error-item:last-child{border-bottom:none}
  .error-test{font-family:var(--mono);font-size:10px;color:var(--fail);opacity:.8;margin-bottom:4px;word-break:break-word}
  .error-msg{font-family:var(--mono);font-size:11px;color:var(--fail);line-height:1.5;word-break:break-word;padding-left:8px;border-left:2px solid rgba(255,77,106,.3)}

  /* ── Notice box (passed but errors logged) ── */
  .nbox-wrap{padding:12px 20px}
  .nbox{border:1px solid rgba(245,166,35,.4);border-left:3px solid var(--unk);border-radius:6px;padding:10px 14px;background:var(--unk-bg)}
  .nbox-lbl{font-family:var(--mono);font-size:9px;text-transform:uppercase;letter-spacing:.12em;color:var(--unk);opacity:.7;margin-bottom:6px}
  .nbox-row{margin-top:6px;padding-left:8px;border-left:2px solid rgba(245,166,35,.4)}
  .nbox-path{font-family:var(--mono);font-size:10px;color:var(--unk);opacity:.75;margin-bottom:2px}
  .nbox-msg{font-family:var(--mono);font-size:11px;color:var(--unk);line-height:1.5;word-break:break-word}

  /* ── No-subtests placeholder ── */
  .empty-row{display:flex;align-items:center;padding:10px 20px 10px 48px;border-bottom:1px solid var(--bdr)}
  .empty-name{font-family:var(--mono);font-size:12px;color:var(--dim);flex:1}

  .foot{text-align:center;margin-top:40px;padding-top:20px;border-top:1px solid var(--bdr);font-family:var(--mono);font-size:10px;color:var(--dim);letter-spacing:.06em}
  @keyframes fu{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
  @media(max-width:800px){.page{padding:20px}.metrics{grid-template-columns:repeat(2,1fr)}.hdr{padding:16px 20px}}
</style>
</head>
<body>

<header class="hdr">
  <div class="hdr-l">
    <div class="logo">
      <svg viewBox="0 0 24 24"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
    </div>
    <div>
      <div class="htitle">HPC TEST REPORT</div>
      <div class="hsub">Execution Summary</div>
    </div>
  </div>
  <div class="hmeta">Generated<span>{{.DateTime}}</span></div>
</header>

<div class="page">

  <div class="metrics">
    <div class="mc mc-total" style="animation-delay:0s">
      <div class="ml">Total Tests</div><div class="mv">{{.TotalTests}}</div>
    </div>
    <div class="mc mc-pass" style="animation-delay:.05s">
      <div class="ml">Passed</div><div class="mv">{{.TotalPass}}</div>
    </div>
    <div class="mc mc-fail" style="animation-delay:.1s">
      <div class="ml">Failed</div><div class="mv">{{.TotalFail}}</div>
    </div>
    <div class="mc mc-time" style="animation-delay:.15s">
      <div class="ml">Total Time</div>
      <div class="mv">{{printf "%.2f" .TotalTime}}<span style="font-size:13px;color:var(--dim);margin-left:3px">min</span></div>
    </div>
  </div>

  <div class="ph">
    <div class="ptitle">Test Groups</div>
    <div class="pcount">{{len .GroupedTests}} groups &middot; {{.TotalTests}} tests</div>
  </div>

  {{range $g := .GroupedTests}}
  <div class="gcard open{{if eq $g.Status "FAIL"}} fail-card{{end}}">

    {{/* Header — onclick here only */}}
    <div class="ghdr" onclick="this.closest('.gcard').classList.toggle('open')">
      <div class="ghdr-l">
        <svg class="chev" viewBox="0 0 24 24"><polyline points="9 18 15 12 9 6"/></svg>
        <span class="gname">{{$g.Name}}</span>
        {{template "pill" $g.Status}}
      </div>
      <span class="gtime">{{printf "%.2f" $g.TotalTime}} min</span>
    </div>

    <div class="gbody">

      {{if $g.Stages}}
        {{range $s := $g.Stages}}

        {{/* Depth-1 stage row — clickable only when it has children */}}
        <div class="srow{{if $s.Children}} has-children{{end}}"
             {{if $s.Children}}onclick="this.classList.toggle('open')"{{end}}>
          <div class="srow-l">
            <svg class="schev" viewBox="0 0 24 24"><polyline points="9 18 15 12 9 6"/></svg>
            <span class="sname">{{$s.Name}}</span>
          </div>
          <span class="sstatus">{{template "pill" $s.Status}}</span>
          <span class="stime">{{printf "%.3f" $s.Elapsed}} min</span>
        </div>

        {{/* Depth-2 leaf rows — hidden until parent stage is toggled */}}
        {{if $s.Children}}
        <div class="children">
          {{range $c := $s.Children}}
          <div class="lrow">
            <span class="lname">{{$c.Name}}</span>
            <span class="lstatus">{{template "pill" $c.Status}}</span>
            <span class="ltime">{{printf "%.3f" $c.Elapsed}} min</span>
          </div>
          {{end}}
        </div>
        {{end}}

        {{end}}
      {{else}}
        {{/* No subtests at all */}}
        <div class="empty-row">
          <span class="empty-name">No subtests</span>
          <span class="sstatus">{{template "pill" $g.Status}}</span>
          <span class="stime">0.000 min</span>
        </div>
      {{end}}

      {{/* Error / notice box */}}
      {{if $g.Errors}}
        {{if eq $g.Status "FAIL"}}
        <div class="ebox-wrap">
          <div class="ebox">
            <div class="ebox-lbl">&#10060; Failure Details</div>
            {{range $e := $g.Errors}}
            <div class="error-item">
              <div class="error-test">{{splitPath $e}}</div>
              <div class="error-msg">{{splitMsg $e}}</div>
            </div>
            {{end}}
          </div>
        </div>
        {{else}}
        <div class="nbox-wrap">
          <div class="nbox">
            <div class="nbox-lbl">&#9888; Errors logged (test passed per runner)</div>
            {{range $e := $g.Errors}}
            <div class="nbox-row">
              <div class="nbox-path">{{splitPath $e}}</div>
              <div class="nbox-msg">{{splitMsg $e}}</div>
            </div>
            {{end}}
          </div>
        </div>
        {{end}}
      {{end}}

    </div>
  </div>
  {{end}}

  <div class="foot">
    HPC Test Runner &nbsp;·&nbsp; {{.DateTime}} &nbsp;·&nbsp; {{.TotalTests}} tests executed
  </div>

</div>

{{/* Reusable pill sub-template */}}
{{define "pill"}}
  {{if eq . "PASS"}}<span class="pill pp">PASS</span>
  {{else if eq . "FAIL"}}<span class="pill pf">FAIL</span>
  {{else}}<span class="pill pu">{{.}}</span>{{end}}
{{end}}

<script>
  // Stage-row children toggle is handled inline via onclick on .srow.
  // No global JS needed — kept minimal intentionally.
</script>
</body>
</html>`
