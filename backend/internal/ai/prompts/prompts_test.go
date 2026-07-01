package prompts

import (
	"strings"
	"testing"
)

func TestBuildAnalysisUserIncludesTranscript(t *testing.T) {
	out := BuildAnalysisUser("John will send the report tomorrow")
	if !strings.Contains(out, "John will send the report tomorrow") {
		t.Errorf("user prompt missing transcript: %q", out)
	}
}

func TestSystemPromptNonEmpty(t *testing.T) {
	if strings.TrimSpace(AnalysisSystemPrompt) == "" {
		t.Error("AnalysisSystemPrompt is empty")
	}
}
