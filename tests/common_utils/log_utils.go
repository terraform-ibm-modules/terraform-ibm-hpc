package tests

import (
	"log"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/logger"
)

// AggregatedLogger represents an aggregated logger with different log levels.
type AggregatedLogger struct {
	infoLogger  *log.Logger
	warnLogger  *log.Logger
	errorLogger *log.Logger
	passLogger  *log.Logger
	failLogger  *log.Logger
}

// NewAggregatedLogger creates a new instance of AggregatedLogger.
func NewAggregatedLogger(logFileName string) (*AggregatedLogger, error) {

	absPath, err := filepath.Abs("test_output")
	if err != nil {
		return nil, err
	}

	file, err := os.Create(filepath.Join(absPath, logFileName))
	if err != nil {
		return nil, err
	}

	return &AggregatedLogger{
		infoLogger:  log.New(file, "", 0),
		warnLogger:  log.New(file, "", 0),
		errorLogger: log.New(file, "", 0),
		passLogger:  log.New(file, "", 0),
		failLogger:  log.New(file, "", 0),
	}, nil
}

// getLogArgs is a helper function to generate common log arguments.
func getLogArgs(t *testing.T, message string) []interface{} {
	return []interface{}{
		time.Now().Format("2006-01-02 15:04:05"),
		t.Name(),
		message,
	}
}

// Info logs informational messages.
func (l *AggregatedLogger) Info(t *testing.T, message string) {
	format := "[%s] [INFO]  [%s] : %v\n"
	l.infoLogger.Printf(format, getLogArgs(t, message)...)
}

// Warn logs warning messages.
func (l *AggregatedLogger) Warn(t *testing.T, message string) {
	format := "[%s] [WARN]  [%s] : %v\n"
	l.warnLogger.Printf(format, getLogArgs(t, message)...)
}

// Error logs error messages.
func (l *AggregatedLogger) Error(t *testing.T, message string) {
	format := "[%s] [ERROR] [%s] : %v\n"
	l.errorLogger.Printf(format, getLogArgs(t, message)...)
	logger.Log(t, getLogArgs(t, message)...)
}

// Error logs error messages.
func (l *AggregatedLogger) PASS(t *testing.T, message string) {
	format := "[%s] [PASS] [%s] : %v\n"
	l.passLogger.Printf(format, getLogArgs(t, message)...)
	logger.Log(t, getLogArgs(t, message)...)
}

// Error logs error messages.
func (l *AggregatedLogger) FAIL(t *testing.T, message string) {
	format := "[%s] [FAIL] [%s] : %v\n"
	l.failLogger.Printf(format, getLogArgs(t, message)...)
	logger.Log(t, getLogArgs(t, message)...)
}
