package handlers

import (
	"time"

	"meetingmind/internal/models"
)

// MeetingResponse is the API view of a meeting. Internal fields (audio key,
// transcript) are intentionally omitted.
type MeetingResponse struct {
	ID        string                   `json:"id"`
	Status    models.ProcessingStatus  `json:"status"`
	Knowledge *models.MeetingKnowledge `json:"knowledge"`
	Error     string                   `json:"error"`
}

func toMeetingResponse(m *models.Meeting) MeetingResponse {
	return MeetingResponse{
		ID:        m.ID.String(),
		Status:    m.Status,
		Knowledge: m.Knowledge,
		Error:     m.ErrorMessage,
	}
}

// MeetingListItem is the compact history row — no knowledge payload.
type MeetingListItem struct {
	ID        string                  `json:"id"`
	Status    models.ProcessingStatus `json:"status"`
	Title     string                  `json:"title"`
	CreatedAt time.Time               `json:"created_at"`
}

func toMeetingListItem(m *models.Meeting) MeetingListItem {
	title := ""
	if m.Knowledge != nil {
		title = m.Knowledge.Title
	}
	return MeetingListItem{
		ID:        m.ID.String(),
		Status:    m.Status,
		Title:     title,
		CreatedAt: m.CreatedAt,
	}
}

func errorEnvelope(code, message string) map[string]any {
	return map[string]any{"error": map[string]string{"code": code, "message": message}}
}
