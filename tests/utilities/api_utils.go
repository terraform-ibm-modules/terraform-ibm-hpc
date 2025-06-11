package tests

import (
	"fmt"
	"net/http"
	"time"
)

// CheckAPIStatus sends a GET request to the given URL and returns the status code
func CheckAPIStatus(url string) (int, error) {
	client := http.Client{
		Timeout: 10 * time.Second, // Set timeout for the request
	}

	resp, err := client.Get(url)
	if err != nil {
		return 0, err
	}

	defer func() {
		if err := resp.Body.Close(); err != nil {
			fmt.Printf("warning: failed to close response body: %v\n", err)
		}
	}()

	return resp.StatusCode, nil
}
