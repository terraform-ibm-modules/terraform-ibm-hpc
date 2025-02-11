package tests

import (
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
	defer resp.Body.Close()

	return resp.StatusCode, nil
}
