package handlers

import "meetingmind/internal/models"

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

func errorEnvelope(code, message string) map[string]any {
	return map[string]any{"error": map[string]string{"code": code, "message": message}}
}
