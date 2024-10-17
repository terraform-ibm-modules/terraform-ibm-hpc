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

// TestResult holds the result of a single test
type TestResult struct {
	Test    string  // Test case name
	Action  string  // PASS or FAIL
	Elapsed float64 // Time elapsed in seconds
}

// ReportData holds the data for the HTML report
type ReportData struct {
	Tests      []TestResult // List of test results
	TotalTests int          // Total number of tests
	TotalPass  int          // Total number of passing tests
	TotalFail  int          // Total number of failing tests
	TotalTime  float64      // Total time taken for all tests
	ChartData  string       // JSON data for charts
	DateTime   string       // Date and time of report generation
}

// ParseLogFile parses the log file and generates a list of TestResult
func ParseJSONFile(fileName string) ([]TestResult, error) {
	file, err := os.Open(fileName)
	if err != nil {
		return nil, fmt.Errorf("error opening log file: %w", err)
	}
	defer file.Close()

	// Regular expression to capture results
	reTestResult := regexp.MustCompile(`--- (PASS|FAIL): (\S+) \((\d+\.\d+)s\)`)

	var results []TestResult
	var testName string

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()

		if matches := reTestResult.FindStringSubmatch(line); matches != nil {
			// Ensure that the testName is set
			if testName == "" {
				testName = matches[2] // Use the test name from the result line as a fallback
			}
			elapsed := parseElapsed(matches[3])
			results = append(results, TestResult{
				Test:    testName,
				Action:  matches[1],
				Elapsed: elapsed,
			})
			// Reset the testName after it has been used
			testName = ""
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading file: %w", err)
	}

	return results, nil
}

// Convert elapsed time from string to float64
func parseElapsed(elapsedStr string) float64 {
	var elapsed float64
	_, err := fmt.Sscanf(elapsedStr, "%f", &elapsed)
	if err != nil {
		fmt.Printf("Error parsing elapsed time :  %s", err)
		return 0.0
	}
	return elapsed
}

// GenerateHTMLReport generates an HTML report from the test results
func GenerateHTMLReport(results []TestResult) error {
	totalTests := len(results)
	totalPass := 0
	totalFail := 0
	totalTime := 0.0
	for _, result := range results {
		if result.Action == "PASS" {
			totalPass++
		} else if result.Action == "FAIL" {
			totalFail++
		}
		totalTime += result.Elapsed
	}

	// Prepare chart data
	chartData := map[string]interface{}{
		"labels": []string{"PASS", "FAIL"},
		"data":   []int{totalPass, totalFail},
	}
	chartDataJSON, err := json.Marshal(chartData)
	if err != nil {
		return fmt.Errorf("error marshaling chart data: %w", err)
	}

	currentTime := time.Now().Format("2006-01-02 15:04:05")

	reportData := ReportData{
		Tests:      results,
		TotalTests: totalTests,
		TotalPass:  totalPass,
		TotalFail:  totalFail,
		TotalTime:  totalTime,
		ChartData:  string(chartDataJSON),
		DateTime:   currentTime,
	}

	htmlTemplate := `
	<!DOCTYPE html>
<html>
<head>
    <title>HPC Test Summary Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { text-align: center; }
        .summary { margin-bottom: 20px; }
        table { width: 60%; float: left; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: center; }
        th { background-color: #f2f2f2; }
        .pass { color: green; }
        .fail { color: red; }
        .chart-container { width: 30%; float: right; margin-top: 20px; }
        .clearfix::after { content: ""; clear: both; display: table; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>HPC Test Summary Report</h1>
    <div class="summary">
        <p>Date and Time: {{.DateTime}}</p>
        <p>Total Tests: {{.TotalTests}}</p>
        <p>Total Pass: {{.TotalPass}}</p>
        <p>Total Fail: {{.TotalFail}}</p>
        <p>Total Time Taken: {{printf "%.2f" .TotalTime}} seconds</p>
    </div>

    <div class="clearfix">
        <table>
            <tr>
                <th>Test Name</th>
                <th>Status</th>
                <th>Elapsed Time (s)</th>
            </tr>
            {{range .Tests}}
            <tr class="{{if eq .Action "PASS"}}pass{{else}}fail{{end}}">
                <td>{{.Test}}</td>
                <td>{{.Action}}</td>
                <td>{{printf "%.2f" .Elapsed}}</td>
            </tr>
            {{end}}
        </table>

        <div class="chart-container">
            <canvas id="testChart" width="400" height="200"></canvas>
        </div>
    </div>

    <script>
        var ctx = document.getElementById('testChart').getContext('2d');
        var chartData = JSON.parse('{{.ChartData}}');
        var myChart = new Chart(ctx, {
            type: 'pie',
            data: {
                labels: chartData.labels,
                datasets: [{
                    label: 'Test Results',
                    data: chartData.data,
                    backgroundColor: ['#4caf50', '#f44336'],
                }]
            }
        });
    </script>
</body>
</html>
	`

	// Parse and execute the HTML template
	tmpl, err := template.New("report").Parse(htmlTemplate)
	if err != nil {
		return fmt.Errorf("error creating template: %w", err)
	}

	reportFileName, ok := os.LookupEnv("LOG_FILE_NAME")
	if ok {
		getFileName := strings.Split(reportFileName, ".")[0]
		// Create or overwrite the report file
		reportFile, err := os.Create(getFileName + ".html")
		if err != nil {
			return fmt.Errorf("error creating report file: %w", err)
		}
		defer reportFile.Close()

		// Execute the template with the data
		err = tmpl.Execute(reportFile, reportData)
		if err != nil {
			return fmt.Errorf("error generating report: %w", err)
		}
		fmt.Printf("HTML report generated: %s.html\n", getFileName)
	}
	return nil
}
