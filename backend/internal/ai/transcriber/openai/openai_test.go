package openai

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestTranscribe(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/audio/transcriptions") {
			t.Errorf("path = %s", r.URL.Path)
		}
		if r.Header.Get("Authorization") != "Bearer sk-test" {
			t.Errorf("auth = %s", r.Header.Get("Authorization"))
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"text":"hello world"}`))
	}))
	defer ts.Close()

	c := New("sk-test", ts.URL, "whisper-1")
	got, err := c.Transcribe(context.Background(), strings.NewReader("fake-audio"))
	if err != nil {
		t.Fatalf("transcribe: %v", err)
	}
	if got != "hello world" {
		t.Errorf("got %q, want hello world", got)
	}
}
