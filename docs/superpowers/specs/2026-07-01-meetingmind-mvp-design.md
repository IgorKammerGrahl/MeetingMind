# MeetingMind — MVP Design Specification

- **Date:** 2026-07-01
- **Status:** Approved design (pre-implementation)
- **Scope:** Single vertical slice of the product described in the project brief

---

## 1. Overview & Scope

MeetingMind records a meeting, transcribes the audio, and uses a Large Language
Model to turn the transcript into **structured meeting knowledge** rendered as an
organized dashboard. The AI is the reasoning engine; the backend orchestrates.

This spec covers a **single vertical slice** that proves the core loop end to end:

```
record → upload → transcribe → analyze → structured knowledge → display
```

### In scope (MVP)

- Mobile audio recording (start / pause / resume / stop) and upload.
- Asynchronous backend pipeline with a typed processing lifecycle.
- Speech-to-text transcription behind a provider interface.
- Transcript → structured `MeetingKnowledge` behind a provider interface.
- Persistence of meeting state + extracted knowledge in PostgreSQL.
- Polling API for the mobile app to track progress and fetch results.
- Mobile dashboard rendering (see §10 for what renders in the MVP).

### Out of scope (deferred, but architecture must not preclude them)

- Authentication, user registration, sessions.
- Meeting history list, delete, and reprocess endpoints.
- Task completion / interaction, offline cache (Hive).
- Calendar/task sync, notifications, team workspaces, semantic search, chat.

### Single-user assumption

No authentication in the MVP. Every meeting is attributed to a **constant
`user_id`** so the schema and domain are multi-user-ready and adding auth later
requires no migration or domain rework.

---

## 2. Architecture

Layered clean architecture with dependency inversion. Dependencies point inward;
outer layers depend on interfaces defined by inner layers.

```
handlers (HTTP / Gin)
   │  depends on
services (orchestration, business rules)
   │  depends on interfaces ↓
repositories   ai.Transcriber   ai.Analyzer   storage.Storage
(GORM/Postgres)  (Whisper impl)   (LLM impl)    (local FS impl)
```

- **Handlers** parse/validate HTTP, call services, map results to DTOs. No
  business logic.
- **Services** own orchestration and the processing lifecycle. Depend only on
  interfaces (`Repository`, `Transcriber`, `Analyzer`, `Storage`).
- **Adapters** (repositories, AI providers, storage) implement those interfaces.
- **Dependency injection** is manual constructor wiring in `cmd/server/main.go`.
  No DI framework.

**Deliberate simplification:** the pipeline runs in an in-process goroutine, not
a durable queue. A crash mid-pipeline leaves a meeting stuck in a non-terminal
status. Acceptable for a single-user MVP.
`// ponytail: in-process worker; swap to a durable queue (asynq/Redis) when multi-user or crash-safety matters.`

---

## 3. Processing Pipeline & Status Lifecycle

`ProcessingStatus` is a **typed enum** (Go string-based type with validated
constants), not a free-form string.

| Status         | Meaning                                             |
|----------------|-----------------------------------------------------|
| `uploaded`     | Audio validated and stored; work not yet started.   |
| `transcribing` | Transcription in progress.                          |
| `analyzing`    | Transcript ready; LLM analysis in progress.         |
| `completed`    | Knowledge extracted and persisted. Terminal.        |
| `failed`       | A stage failed; see `failed_stage` + `error`. Terminal. |

### Flow

1. `POST /meetings/upload`: validate → `Storage.Save(audio)` → create meeting
   `{status: uploaded}` → return `202 {id, status}` → dispatch background worker.
2. Worker (background context, not the request context):
   - set `transcribing` → `Transcriber.Transcribe(audio)` → persist transcript
   - set `analyzing` → `Analyzer.Analyze(transcript)` → persist knowledge
   - set `completed`
3. On error at any stage: set `failed`, record `failed_stage` and `error`, log.
4. Audio file is deleted from storage after the pipeline reaches a terminal
   status (success or failure).

The mobile app maps statuses to progress copy (e.g. "Transcribing…",
"Analyzing…") while polling.

---

## 4. Domain Model

The domain centers on **extracted meeting knowledge**, expressed as typed Go
structs — never `map[string]interface{}` or an opaque JSON blob passed between
layers. Persistence serializes these typed structs to `jsonb` (an
implementation detail of the repository), but every layer above the repository
works with the rich types.

```
Meeting
├── ID            uuid
├── UserID        string        (constant in MVP)
├── Status        ProcessingStatus
├── FailedStage   *Stage        (nil unless failed)
├── ErrorMessage  string
├── AudioKey      string        (storage key; cleared after cleanup)
├── Transcript    string
├── Knowledge     *MeetingKnowledge   (nil until analysis completes)
├── CreatedAt / UpdatedAt

MeetingKnowledge
├── Title         string
├── Summary       string
├── MeetingType   MeetingType   (enum, AI-inferred)
├── Participants  []Participant
├── Tasks         []Task
├── Decisions     []Decision
├── Reminders     []Reminder
├── PendingItems  []PendingItem
├── FollowUp      []FollowUpAction
├── Risks         []Risk
├── Questions     []Question
└── Keywords      []string
```

### Value types

| Type             | Fields                                                    |
|------------------|----------------------------------------------------------|
| `Participant`    | `Name`, `Role` (optional)                                |
| `Task`           | `Responsible`, `Task`, `Deadline`, `Priority`            |
| `Decision`       | `Description`                                             |
| `Reminder`       | `Description`                                             |
| `PendingItem`    | `Description`                                             |
| `FollowUpAction` | `Description`, `Responsible` (optional)                   |
| `Risk`           | `Description`, `Severity`                                 |
| `Question`       | `Question` (a clarification the user should ask)         |

### Enums

- `Priority`: `low | medium | high`
- `Severity`: `low | medium | high`
- `MeetingType`: `standup | class | lecture | presentation | one_on_one | brainstorm | interview | general | other`
- `Stage`: `transcription | analysis` (used for `FailedStage`)

`Deadline` is stored as the string the AI produces (may be relative, e.g.
"tomorrow"). Normalizing to an absolute date is deferred.
`// ponytail: keep AI-provided deadline string; add date normalization when tasks become interactive.`

---

## 5. AI Layer

The AI layer is organized into subpackages, with prompts separated from the
provider/business logic.

```
internal/ai/
├── transcriber/
│   ├── transcriber.go      # Transcriber interface + domain errors
│   └── openai/             # Whisper (whisper-1) implementation
├── analyzer/
│   ├── analyzer.go         # Analyzer interface + domain errors
│   └── openai/             # gpt-4o-mini implementation (Structured Outputs)
└── prompts/                # prompt templates (no business logic, no SDK calls)
```

### Interfaces (defined by the inner layer, implemented by adapters)

```go
type Transcriber interface {
    Transcribe(ctx context.Context, audio io.Reader) (string, error)
}

type Analyzer interface {
    Analyze(ctx context.Context, transcript string) (*models.MeetingKnowledge, error)
}
```

- **Transcriber** — MVP impl: OpenAI Whisper (`whisper-1`). Note: Anthropic has
  no STT API, so the Transcriber intentionally targets a dedicated STT vendor.
- **Analyzer** — MVP impl: OpenAI `gpt-4o-mini` using **Structured Outputs
  (`json_schema`)** so the returned JSON is schema-guaranteed and deserializes
  cleanly into `MeetingKnowledge`. A future Anthropic (Claude) adapter is a
  drop-in behind this interface plus a config change.

### Prompts package

`internal/ai/prompts` holds prompt templates and field-level extraction guidance
as data/constants — no SDK calls, no orchestration. The analyzer adapter calls
into it (e.g. `prompts.AnalysisSystemPrompt`, `prompts.BuildAnalysisUser(transcript)`).

**Provider-specific vs. canonical:** the canonical knowledge shape is the Go
`MeetingKnowledge` struct. Each analyzer adapter is responsible for translating
that shape into its provider's schema format (OpenAI `json_schema` vs. Anthropic
tool schema). Natural-language instructions live in `prompts`; the provider
schema encoding lives in the adapter.

---

## 6. Storage Abstraction

A dedicated `Storage` interface decouples the pipeline from where audio lives.
The MVP ships one implementation (local filesystem); an object-store adapter
(S3/GCS) is a future drop-in.

```go
type Storage interface {
    Save(ctx context.Context, key string, r io.Reader) error
    Open(ctx context.Context, key string) (io.ReadCloser, error)
    Delete(ctx context.Context, key string) error
}
```

- `internal/storage/local` — writes under `TEMP_DIR`, keyed by meeting id.
- The pipeline `Open`s the audio for transcription and `Delete`s it once the
  meeting reaches a terminal status.

---

## 7. Persistence

- PostgreSQL via GORM. Schema managed with GORM `AutoMigrate` for the MVP.
  `// ponytail: AutoMigrate is fine for the slice; adopt a migration tool (goose/atlas) before schema churn in a team.`
- Single `meetings` table:

| Column          | Type      | Notes                                     |
|-----------------|-----------|-------------------------------------------|
| `id`            | uuid (PK) |                                           |
| `user_id`       | text      | constant in MVP; indexed for future lists |
| `status`        | text      | `ProcessingStatus` enum value             |
| `failed_stage`  | text null | set only on failure                       |
| `error_message` | text null |                                           |
| `audio_key`     | text null | storage key; cleared after cleanup        |
| `transcript`    | text null |                                           |
| `knowledge`     | jsonb null| serialized `MeetingKnowledge`             |
| `created_at`    | timestamptz |                                         |
| `updated_at`    | timestamptz |                                         |

- `knowledge` is serialized/deserialized via a GORM JSON serializer so the
  repository exchanges typed `*MeetingKnowledge` with the rest of the app — the
  jsonb column is an implementation detail, not a leaked blob.
- Tasks and other sections are **not** normalized into separate tables in the
  MVP; they live inside `knowledge`. Normalization is deferred until they become
  independently queryable/interactive.

---

## 8. API

REST/JSON. MVP endpoints only:

### `POST /meetings/upload`
- Request: `multipart/form-data`, field `audio` (recorded file).
- Validation: file present, size ≤ `MAX_UPLOAD_MB`, allowed audio extension/type.
- Success: `202 Accepted`
  ```json
  { "id": "uuid", "status": "uploaded" }
  ```
- Validation failure: `400` with error body.

### `GET /meetings/:id`
- Success: `200`
  ```json
  {
    "id": "uuid",
    "status": "uploaded | transcribing | analyzing | completed | failed",
    "knowledge": null,
    "error": null
  }
  ```
- When `status == completed`, `knowledge` is populated:
  ```json
  {
    "title": "",
    "summary": "",
    "meeting_type": "standup",
    "participants": [ { "name": "", "role": "" } ],
    "tasks": [ { "responsible": "", "task": "", "deadline": "", "priority": "medium" } ],
    "decisions": [ { "description": "" } ],
    "reminders": [ { "description": "" } ],
    "pending_items": [ { "description": "" } ],
    "follow_up": [ { "description": "", "responsible": "" } ],
    "risks": [ { "description": "", "severity": "low" } ],
    "questions": [ { "question": "" } ],
    "keywords": [ "" ]
  }
  ```
- When `status == failed`, `error` carries a user-safe message.
- Unknown id: `404`.

### Error envelope

```json
{ "error": { "code": "validation_error", "message": "human-readable" } }
```

Deferred endpoints (design accommodates them without rework): `POST /auth/*`,
`GET /meetings`, `DELETE /meetings/:id`, `POST /meetings/:id/reprocess`.

---

## 9. Backend Project Structure

Follows the brief's suggested layout.

```
backend/
├── cmd/server/main.go              # config load + manual DI wiring
├── internal/
│   ├── config/                     # env config struct + loader
│   ├── handlers/                   # gin handlers (meeting_handler.go), DTOs
│   ├── services/                   # meeting_service.go (orchestration + lifecycle)
│   ├── repositories/               # meeting_repository.go (GORM)
│   ├── models/                     # Meeting, MeetingKnowledge, value types, enums
│   ├── middleware/                 # logging, recovery, CORS
│   ├── ai/
│   │   ├── transcriber/            # interface + openai/ (whisper)
│   │   ├── analyzer/               # interface + openai/ (gpt-4o-mini)
│   │   └── prompts/                # templates
│   ├── storage/                    # Storage interface + local/
│   └── database/                   # gorm connection + AutoMigrate
├── pkg/                            # shared utilities if any emerge (empty at start)
├── docker-compose.yml              # local PostgreSQL
├── .env.example
└── go.mod
```

---

## 10. Mobile Design (Flutter)

Stack: Flutter + Riverpod (state) + GoRouter (nav) + Dio (HTTP) + `record` (audio).
Hive is **deferred** (no history/offline in the slice).

### Screens (GoRouter)

1. **Record** — start / pause / resume / stop via `record`; produces a local
   audio file; "Process" action triggers upload.
2. **Processing** — shown after upload; a Riverpod provider polls
   `GET /meetings/:id` every ~3s, displaying status-mapped progress copy. Poll
   loop has a ~3-minute timeout → error state. `failed` status → error + retry.
3. **Dashboard** — renders extracted knowledge.

### MVP rendering decision

The backend extracts the **full** `MeetingKnowledge`. The MVP dashboard renders
**Summary + Tasks** as the primary cards (title header, summary card, task cards
with responsible / deadline / priority chips). The remaining sections
(participants, decisions, reminders, pending_items, follow_up, risks, questions,
keywords) are returned by the API and can be surfaced as additional cards in a
fast follow. *(Confirm during spec review if all sections should render now.)*

### Mobile structure

```
mobile/lib/
├── main.dart
├── core/         # dio client, config, theme, router
├── data/         # api client, JSON models (mirror knowledge schema), repository
├── providers/    # riverpod providers (upload, polling)
└── features/
    ├── recording/  # record screen
    └── meeting/    # processing + dashboard screens, widgets (cards)
```

---

## 11. Configuration (env)

| Var               | Purpose                       | Default        |
|-------------------|-------------------------------|----------------|
| `OPENAI_API_KEY`  | Whisper + analyzer auth       | — (required)   |
| `DATABASE_URL`    | PostgreSQL DSN                | —              |
| `STT_MODEL`       | transcription model           | `whisper-1`    |
| `ANALYZER_MODEL`  | analysis model                | `gpt-4o-mini`  |
| `PORT`            | HTTP port                     | `8080`         |
| `MAX_UPLOAD_MB`   | upload size limit             | `25`           |
| `TEMP_DIR`        | local audio storage dir       | `./tmp/audio`  |

---

## 12. Error Handling

- **Upload validation** (missing file, too large, bad type) → `400` + error
  envelope; nothing persisted.
- **Pipeline failures** (transcription or analysis) → meeting set to `failed`
  with `failed_stage` + user-safe `error`; full detail logged server-side; audio
  cleaned up.
- **Analyzer output** — Structured Outputs guarantees schema shape; the adapter
  still deserializes defensively and treats a decode failure as an analysis-stage
  failure.
- **Mobile** — upload failure → retry affordance; poll timeout / `failed` →
  error state with retry; defensive JSON decoding.

---

## 13. Testing Strategy

Lightweight, standard tooling only (Go `testing` + `httptest`; Flutter
`flutter_test`). No mocking frameworks or fixtures beyond hand-written fakes.

**Backend**
- Service test with fake `Transcriber` / `Analyzer` / `Storage` / repository:
  asserts the status lifecycle (`uploaded → transcribing → analyzing →
  completed`) and the failure path (`failed` + `failed_stage`).
- Analyzer adapter test: sample provider JSON → `MeetingKnowledge` struct.
- Handler test: upload validation (missing/oversized file → `400`).

**Mobile**
- Dashboard widget test: renders summary + task cards from a sample `knowledge`.
- Polling provider test: transitions to done/error correctly.

---

## 14. Deliberate Simplifications & Future Extensions

| Simplification (MVP)                       | Upgrade path                                  |
|--------------------------------------------|-----------------------------------------------|
| In-process goroutine worker                | Durable queue (asynq/Redis) for scale/safety  |
| GORM `AutoMigrate`                         | Migration tool (goose/atlas)                  |
| Local filesystem storage                   | S3/GCS `Storage` adapter (interface ready)    |
| Constant `user_id`, no auth                | Auth middleware + real user ids (schema ready)|
| Knowledge as jsonb, no normalized tables   | Normalize when sections become queryable      |
| OpenAI analyzer                            | Anthropic/Claude analyzer adapter (drop-in)   |
| AI-provided deadline string                | Absolute-date normalization                   |
| No Hive cache                              | Offline history/cache                         |

The interface boundaries (`Transcriber`, `Analyzer`, `Storage`, `Repository`)
are the seams that make each of these additive rather than a refactor.

---

## 15. Points to Confirm in Spec Review

1. Mobile MVP renders Summary + Tasks only vs. all extracted sections (§10).
2. `MeetingType` enum value set (§4) — adjust to your expected meeting kinds.
3. Upload size limit (`MAX_UPLOAD_MB = 25`) and allowed audio formats.
