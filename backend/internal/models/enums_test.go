package models

import "testing"

func TestProcessingStatusIsValid(t *testing.T) {
	valid := []ProcessingStatus{StatusUploaded, StatusTranscribing, StatusAnalyzing, StatusCompleted, StatusFailed}
	for _, s := range valid {
		if !s.IsValid() {
			t.Errorf("%q should be valid", s)
		}
	}
	if ProcessingStatus("bogus").IsValid() {
		t.Error("bogus should be invalid")
	}
}
