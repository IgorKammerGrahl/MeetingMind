package analyzer

import (
	"context"

	"meetingmind/internal/models"
)

// Analyzer turns a transcript into structured meeting knowledge.
type Analyzer interface {
	Analyze(ctx context.Context, transcript string) (*models.MeetingKnowledge, error)
}
