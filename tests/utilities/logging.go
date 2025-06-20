package tests

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// LogLevel represents different logging levels
type LogLevel string

const (
	LevelInfo  LogLevel = "INFO"
	LevelWarn  LogLevel = "WARN"
	LevelError LogLevel = "ERROR"
	LevelPass  LogLevel = "PASS"
	LevelFail  LogLevel = "FAIL"
	LevelDebug LogLevel = "DEBUG"
)

// AggregatedLogger provides multi-level logging capabilities
type AggregatedLogger struct {
	loggers map[LogLevel]*log.Logger
	file    *os.File
}

// NewAggregatedLogger creates a new logger instance with file output
func NewAggregatedLogger(logFileName string) (*AggregatedLogger, error) {
	// Ensure logs directory exists
	logsDir := filepath.Join("logs_output")
	if err := os.MkdirAll(logsDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create logs directory: %w", err)
	}

	// Create log file
	filePath := filepath.Join(logsDir, logFileName)
	file, err := os.OpenFile(filePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return nil, fmt.Errorf("failed to create log file: %w", err)
	}

	// Create multi-writer for console and file output
	multiWriter := io.MultiWriter(os.Stdout, file)

	return &AggregatedLogger{
		loggers: map[LogLevel]*log.Logger{
			LevelInfo:  log.New(multiWriter, string(LevelInfo)+" ", log.Lmsgprefix),
			LevelWarn:  log.New(multiWriter, string(LevelWarn)+" ", log.Lmsgprefix),
			LevelError: log.New(multiWriter, string(LevelError)+" ", log.Lmsgprefix),
			LevelPass:  log.New(multiWriter, string(LevelPass)+" ", log.Lmsgprefix),
			LevelFail:  log.New(multiWriter, string(LevelFail)+" ", log.Lmsgprefix),
			LevelDebug: log.New(multiWriter, string(LevelDebug)+" ", log.Lmsgprefix),
		},
		file: file,
	}, nil
}

// Close releases resources used by the logger
func (l *AggregatedLogger) Close() error {
	if l.file != nil {
		return l.file.Close()
	}
	return nil
}

// logInternal is the internal logging function
func (l *AggregatedLogger) logInternal(t *testing.T, level LogLevel, message string) {
	if logger, exists := l.loggers[level]; exists {
		logger.Printf("[%s] [%s] %s",
			time.Now().Format("2006-01-02 15:04:05"),
			t.Name(),
			message,
		)
	}
}

// Info logs informational messages
func (l *AggregatedLogger) Info(t *testing.T, message string) {
	l.logInternal(t, LevelInfo, message)
}

// Warn logs warning messages
func (l *AggregatedLogger) Warn(t *testing.T, message string) {
	l.logInternal(t, LevelWarn, message)
}

// Error logs error messages
func (l *AggregatedLogger) Error(t *testing.T, message string) {
	l.logInternal(t, LevelError, message)
}

// PASS logs successful test messages
func (l *AggregatedLogger) PASS(t *testing.T, message string) {
	l.logInternal(t, LevelPass, message)
}

// FAIL logs failed test messages
func (l *AggregatedLogger) FAIL(t *testing.T, message string) {
	l.logInternal(t, LevelFail, message)
}

// DEBUG logs debugging messages
func (l *AggregatedLogger) DEBUG(t *testing.T, message string) {
	l.logInternal(t, LevelDebug, message)
}

// LogValidationResult provides a consistent way to log validation results
func (l *AggregatedLogger) LogValidationResult(t *testing.T, success bool, message string) {
	if success {
		l.PASS(t, fmt.Sprintf("Validation succeeded : %s", message))
	} else {
		l.FAIL(t, fmt.Sprintf("Validation failed : %s", message))
	}
}
