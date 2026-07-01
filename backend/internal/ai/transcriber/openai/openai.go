package openai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
)

const defaultBaseURL = "https://api.openai.com/v1"

// Client is an OpenAI Whisper transcriber.
type Client struct {
	apiKey  string
	baseURL string
	model   string
	http    *http.Client
}

func New(apiKey, baseURL, model string) *Client {
	if baseURL == "" {
		baseURL = defaultBaseURL
	}
	return &Client{apiKey: apiKey, baseURL: baseURL, model: model, http: http.DefaultClient}
}

func (c *Client) Transcribe(ctx context.Context, audio io.Reader) (string, error) {
	var body bytes.Buffer
	w := multipart.NewWriter(&body)

	fw, err := w.CreateFormFile("file", "audio")
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(fw, audio); err != nil {
		return "", err
	}
	if err := w.WriteField("model", c.model); err != nil {
		return "", err
	}
	if err := w.Close(); err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/audio/transcriptions", &body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", w.FormDataContentType())

	resp, err := c.http.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("whisper: status %d: %s", resp.StatusCode, string(b))
	}

	var out struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", err
	}
	return out.Text, nil
}
