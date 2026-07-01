package models

// MeetingKnowledge is the structured output extracted from a transcript.
// JSON tags double as the API contract for the knowledge object.
type MeetingKnowledge struct {
	Title        string           `json:"title"`
	Summary      string           `json:"summary"`
	MeetingType  MeetingType      `json:"meeting_type"`
	Participants []Participant    `json:"participants"`
	Tasks        []Task           `json:"tasks"`
	Decisions    []Decision       `json:"decisions"`
	Reminders    []Reminder       `json:"reminders"`
	PendingItems []PendingItem    `json:"pending_items"`
	FollowUp     []FollowUpAction `json:"follow_up"`
	Risks        []Risk           `json:"risks"`
	Questions    []Question       `json:"questions"`
	Keywords     []string         `json:"keywords"`
}

type Participant struct {
	Name string `json:"name"`
	Role string `json:"role"`
}

type Task struct {
	Responsible string   `json:"responsible"`
	Task        string   `json:"task"`
	Deadline    string   `json:"deadline"`
	Priority    Priority `json:"priority"`
}

type Decision struct {
	Description string `json:"description"`
}

type Reminder struct {
	Description string `json:"description"`
}

type PendingItem struct {
	Description string `json:"description"`
}

type FollowUpAction struct {
	Description string `json:"description"`
	Responsible string `json:"responsible"`
}

type Risk struct {
	Description string   `json:"description"`
	Severity    Severity `json:"severity"`
}

type Question struct {
	Question string `json:"question"`
}
