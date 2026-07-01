package openai

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"meetingmind/internal/models"
)

func TestAnalyzeDeserializes(t *testing.T) {
	knowledge := models.MeetingKnowledge{
		Title:       "Standup",
		Summary:     "Daily sync",
		MeetingType: models.MeetingType("standup"),
		Tasks:       []models.Task{{Responsible: "John", Task: "send document", Deadline: "tomorrow", Priority: models.PriorityMedium}},
	}
	content, _ := json.Marshal(knowledge)

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/chat/completions") {
			t.Errorf("path = %s", r.URL.Path)
		}
		resp := map[string]any{
			"choices": []map[string]any{
				{"message": map[string]any{"content": string(content)}},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer ts.Close()

	c := New("sk-test", ts.URL, "gpt-4o-mini")
	got, err := c.Analyze(context.Background(), "John, could you send that document tomorrow?")
	if err != nil {
		t.Fatalf("analyze: %v", err)
	}
	if got.Title != "Standup" {
		t.Errorf("title = %q, want Standup", got.Title)
	}
	if len(got.Tasks) != 1 || got.Tasks[0].Responsible != "John" {
		t.Errorf("tasks not parsed: %+v", got.Tasks)
	}
}
