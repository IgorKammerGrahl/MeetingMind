package openai

import "encoding/json"

// knowledgeSchema is the OpenAI Structured Outputs JSON schema matching
// models.MeetingKnowledge. Strict mode requires every property listed in
// "required" and additionalProperties:false on every object.
var knowledgeSchema = json.RawMessage(`{
  "type": "object",
  "additionalProperties": false,
  "required": ["title","summary","meeting_type","participants","tasks","decisions","reminders","pending_items","follow_up","risks","questions","keywords"],
  "properties": {
    "title": {"type": "string"},
    "summary": {"type": "string"},
    "meeting_type": {"type": "string", "enum": ["standup","class","lecture","presentation","one_on_one","brainstorm","interview","general","other"]},
    "participants": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["name","role"], "properties": {"name": {"type": "string"}, "role": {"type": "string"}}}},
    "tasks": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["responsible","task","deadline","priority"], "properties": {"responsible": {"type": "string"}, "task": {"type": "string"}, "deadline": {"type": "string"}, "priority": {"type": "string", "enum": ["low","medium","high"]}}}},
    "decisions": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["description"], "properties": {"description": {"type": "string"}}}},
    "reminders": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["description"], "properties": {"description": {"type": "string"}}}},
    "pending_items": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["description"], "properties": {"description": {"type": "string"}}}},
    "follow_up": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["description","responsible"], "properties": {"description": {"type": "string"}, "responsible": {"type": "string"}}}},
    "risks": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["description","severity"], "properties": {"description": {"type": "string"}, "severity": {"type": "string", "enum": ["low","medium","high"]}}}},
    "questions": {"type": "array", "items": {"type": "object", "additionalProperties": false, "required": ["question"], "properties": {"question": {"type": "string"}}}},
    "keywords": {"type": "array", "items": {"type": "string"}}
  }
}`)
