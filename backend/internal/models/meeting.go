package models

import (
	"time"

	"github.com/google/uuid"
)

// Meeting is the persisted aggregate for one recording and its extracted knowledge.
type Meeting struct {
	ID           uuid.UUID         `gorm:"type:uuid;primaryKey"`
	UserID       string            `gorm:"index"`
	Status       ProcessingStatus  `gorm:"type:varchar(20)"`
	FailedStage  *Stage            `gorm:"type:varchar(20)"`
	ErrorMessage string
	AudioKey     string
	Transcript   string
	Knowledge    *MeetingKnowledge `gorm:"serializer:json;type:jsonb"`
	CreatedAt    time.Time
	UpdatedAt    time.Time
}
