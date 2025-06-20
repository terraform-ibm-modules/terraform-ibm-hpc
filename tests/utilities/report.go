package tests

import (
	"bufio"
	"encoding/json"
	"fmt"
	"html/template"
	"os"
	"regexp"
	"strings"
	"time"
)

// TestResult holds the result of a single test case
type TestResult struct {
	Test    string  `json:"test"`    // Name of the test case
	Action  string  `json:"action"`  // Test outcome (PASS/FAIL)
	Elapsed float64 `json:"elapsed"` // Duration in seconds
}

// ReportData contains all data needed to generate the HTML report
type ReportData struct {
	Tests      []TestResult `json:"tests"`      // Individual test results
	TotalTests int          `json:"totalTests"` // Total number of tests
	TotalPass  int          `json:"totalPass"`  // Number of passed tests
	TotalFail  int          `json:"totalFail"`  // Number of failed tests
	TotalTime  float64      `json:"totalTime"`  // Total execution time
	ChartData  string       `json:"chartData"`  // JSON data for charts
	DateTime   string       `json:"dateTime"`   // Report generation timestamp
}

// ParseJSONFile reads and parses a JSON test log file into TestResult structures
func ParseJSONFile(fileName string) ([]TestResult, error) {
	file, err := os.Open(fileName)
	if err != nil {
		return nil, fmt.Errorf("error opening log file: %w", err)
	}
	defer closeFile(file, fileName)

	// Regex to match test result lines (e.g., "--- PASS: TestSomething (0.45s)")
	reTestResult := regexp.MustCompile(`--- (PASS|FAIL): (\S+) \((\d+\.\d+)s\)`)
	var results []TestResult

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		if matches := reTestResult.FindStringSubmatch(scanner.Text()); matches != nil {
			results = append(results, TestResult{
				Test:    matches[2],
				Action:  matches[1],
				Elapsed: parseElapsedTime(matches[3]),
			})
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading log file: %w", err)
	}

	return results, nil
}

// GenerateHTMLReport creates an HTML report from test results
func GenerateHTMLReport(results []TestResult) error {
	if len(results) == 0 {
		return fmt.Errorf("no test results to report")
	}

	// Calculate report statistics
	stats := calculateStats(results)

	// Prepare chart data
	chartData := map[string]interface{}{
		"labels": []string{"PASS", "FAIL"},
		"data":   []int{stats.totalPass, stats.totalFail},
	}
	chartDataJSON, err := json.Marshal(chartData)
	if err != nil {
		return fmt.Errorf("error marshaling chart data: %w", err)
	}

	// Prepare report data
	reportData := ReportData{
		Tests:      results,
		TotalTests: stats.totalTests,
		TotalPass:  stats.totalPass,
		TotalFail:  stats.totalFail,
		TotalTime:  stats.totalTime,
		ChartData:  string(chartDataJSON),
		DateTime:   time.Now().Format("2006-01-02 15:04:05"),
	}

	// Generate and write the report
	return writeReport(reportData)
}

// reportStats holds calculated statistics for the report
type reportStats struct {
	totalTests int
	totalPass  int
	totalFail  int
	totalTime  float64
}

// calculateStats computes summary statistics from test results
func calculateStats(results []TestResult) reportStats {
	var stats reportStats
	stats.totalTests = len(results)

	for _, result := range results {
		switch result.Action {
		case "PASS":
			stats.totalPass++
		case "FAIL":
			stats.totalFail++
		}
		stats.totalTime += result.Elapsed
	}

	return stats
}

// writeReport generates and writes the HTML report file
func writeReport(data ReportData) error {
	tmpl, err := template.New("report").Parse(reportTemplate)
	if err != nil {
		return fmt.Errorf("template parsing failed: %w", err)
	}

	reportFileName := getReportFileName()
	reportFile, err := os.Create(reportFileName)
	if err != nil {
		return fmt.Errorf("error creating report file: %w", err)
	}
	defer closeFile(reportFile, reportFileName)

	// Execute template with cleaned content
	cleanedContent := cleanTemplateOutput(tmpl, data)
	if _, err := reportFile.WriteString(cleanedContent); err != nil {
		return fmt.Errorf("error writing report: %w", err)
	}

	//status
	fmt.Printf("✅ HTML report generated: %s\n", reportFileName)
	return nil
}

// getReportFileName determines the output filename for the report
func getReportFileName() string {
	if logFile, ok := os.LookupEnv("LOG_FILE_NAME"); ok {
		return strings.TrimSuffix(logFile, ".json") + ".html"
	}
	return "test-report-" + time.Now().Format("20060102-150405") + ".html"
}

// parseElapsedTime converts elapsed time string to float64
func parseElapsedTime(elapsedStr string) float64 {
	var elapsed float64
	if _, err := fmt.Sscanf(elapsedStr, "%f", &elapsed); err != nil {
		fmt.Fprintf(os.Stderr, "warning: failed to parse elapsed time '%s': %v\n", elapsedStr, err)
	}
	return elapsed
}

// cleanTemplateOutput processes template output for better HTML formatting
func cleanTemplateOutput(tmpl *template.Template, data interface{}) string {
	var sb strings.Builder
	if err := tmpl.Execute(&sb, data); err != nil {
		fmt.Fprintf(os.Stderr, "warning: template execution error: %v\n", err)
		return ""
	}

	// Clean up whitespace and newlines
	reNewline := regexp.MustCompile(`[\r\n]+`)
	noNewlines := reNewline.ReplaceAllString(sb.String(), " ")
	reWhitespace := regexp.MustCompile(`\s+`)
	cleaned := reWhitespace.ReplaceAllString(noNewlines, " ")
	return strings.TrimSpace(cleaned) + "\n"
}

// closeFile safely closes a file and logs any errors
func closeFile(file *os.File, fileName string) {
	if err := file.Close(); err != nil {
		fmt.Fprintf(os.Stderr, "warning: failed to close file %s: %v\n", fileName, err)
	}
}

// reportTemplate is the HTML template for the test report
const reportTemplate = `<!DOCTYPE html>
<html>
<head>
    <title>HPC Test Summary Report</title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        h1 { color: #2c3e50; text-align: center; margin-bottom: 20px; }
        .summary {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #3498db;
            color: white;
            position: sticky;
            top: 0;
        }
        tr:hover { background-color: #f5f5f5; }
        .pass { color: #27ae60; }
        .fail { color: #e74c3c; }
        .chart-container {
            margin: 30px auto;
            max-width: 500px;
        }
        .metrics {
            display: flex;
            justify-content: space-around;
            flex-wrap: wrap;
            margin: 20px 0;
        }
        .metric {
            text-align: center;
            padding: 15px;
            min-width: 120px;
            background: #ecf0f1;
            border-radius: 5px;
            margin: 5px;
        }
        .metric-value {
            font-size: 24px;
            font-weight: bold;
        }
        .pass-metric { color: #27ae60; }
        .fail-metric { color: #e74c3c; }
        .time-metric { color: #3498db; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>HPC Test Summary Report</h1>

    <div class="summary">
        <h2>Report Summary</h2>
        <p>Generated on: {{.DateTime}}</p>

        <div class="metrics">
            <div class="metric">
                <div>Total Tests</div>
                <div class="metric-value">{{.TotalTests}}</div>
            </div>
            <div class="metric pass-metric">
                <div>Passed</div>
                <div class="metric-value">{{.TotalPass}}</div>
            </div>
            <div class="metric fail-metric">
                <div>Failed</div>
                <div class="metric-value">{{.TotalFail}}</div>
            </div>
            <div class="metric time-metric">
                <div>Total Time</div>
                <div class="metric-value">{{printf "%.2f" .TotalTime}}s</div>
            </div>
        </div>
    </div>

    <div class="chart-container">
        <canvas id="testChart"></canvas>
    </div>

    <h2>Detailed Test Results</h2>
    <table>
        <thead>
            <tr>
                <th>Test Name</th>
                <th>Status</th>
                <th>Duration (s)</th>
            </tr>
        </thead>
        <tbody>
            {{range .Tests}}
            <tr class="{{if eq .Action "PASS"}}pass{{else}}fail{{end}}">
                <td>{{.Test}}</td>
                <td>{{.Action}}</td>
                <td>{{printf "%.3f" .Elapsed}}</td>
            </tr>
            {{end}}
        </tbody>
    </table>

    <script>
        var ctx = document.getElementById('testChart').getContext('2d');
        var chartData = JSON.parse('{{.ChartData}}');
        new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: chartData.labels,
                datasets: [{
                    data: chartData.data,
                    backgroundColor: ['#27ae60', '#e74c3c'],
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'bottom',
                    },
                    title: {
                        display: true,
                        text: 'Test Results Summary',
                        font: {
                            size: 16
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>`
