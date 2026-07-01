package models

// DefaultUserID attributes every meeting to a single user in the MVP (no auth).
const DefaultUserID = "mvp-single-user"

// ProcessingStatus is the typed lifecycle of a meeting.
type ProcessingStatus string

const (
	StatusUploaded     ProcessingStatus = "uploaded"
	StatusTranscribing ProcessingStatus = "transcribing"
	StatusAnalyzing    ProcessingStatus = "analyzing"
	StatusCompleted    ProcessingStatus = "completed"
	StatusFailed       ProcessingStatus = "failed"
)

func (s ProcessingStatus) IsValid() bool {
	switch s {
	case StatusUploaded, StatusTranscribing, StatusAnalyzing, StatusCompleted, StatusFailed:
		return true
	}
	return false
}

// Stage identifies which pipeline stage failed.
type Stage string

const (
	StageTranscription Stage = "transcription"
	StageAnalysis      Stage = "analysis"
)

// Priority of an extracted task.
type Priority string

const (
	PriorityLow    Priority = "low"
	PriorityMedium Priority = "medium"
	PriorityHigh   Priority = "high"
)

// Severity of an extracted risk.
type Severity string

const (
	SeverityLow    Severity = "low"
	SeverityMedium Severity = "medium"
	SeverityHigh   Severity = "high"
)

// MeetingType is the AI-inferred kind of meeting.
type MeetingType string
