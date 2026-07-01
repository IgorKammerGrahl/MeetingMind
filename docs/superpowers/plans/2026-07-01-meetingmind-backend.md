# MeetingMind Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Go backend that accepts a recorded meeting, runs an asynchronous transcribe→analyze pipeline behind provider interfaces, and exposes a polling REST API returning typed meeting knowledge.

**Architecture:** Layered clean architecture (handlers → services → interfaces → adapters). The service owns a typed processing lifecycle and runs the pipeline in a background goroutine. Speech-to-text, LLM analysis, and audio storage each sit behind an interface with one concrete adapter (OpenAI Whisper, OpenAI gpt-4o-mini via Structured Outputs, local filesystem). Extracted knowledge is a rich typed domain model persisted to PostgreSQL as jsonb.

**Tech Stack:** Go 1.26, Gin, GORM (+ postgres driver; glebarez/sqlite for tests), google/uuid, joho/godotenv, OpenAI HTTP APIs.

## Global Constraints

- Module path: `meetingmind`. All internal imports are `meetingmind/internal/...`.
- Go version floor: `go 1.26`.
- Handlers contain no business logic; services depend only on interfaces (`Repository`, `storage.Storage`, `transcriber.Transcriber`, `analyzer.Analyzer`).
- `ProcessingStatus` is a typed enum: `uploaded → transcribing → analyzing → completed → failed`.
- Meeting knowledge is typed Go structs (`models.MeetingKnowledge` + value types) — never `map[string]interface{}`; persisted as jsonb via GORM `serializer:json`.
- Single-user MVP: every meeting uses constant `models.DefaultUserID = "mvp-single-user"`. No auth.
- AI defaults from env: `STT_MODEL=whisper-1`, `ANALYZER_MODEL=gpt-4o-mini`; analyzer uses OpenAI Structured Outputs (`response_format: json_schema`, `strict: true`).
- Config via env: `OPENAI_API_KEY`, `DATABASE_URL`, `STT_MODEL`, `ANALYZER_MODEL`, `PORT=8080`, `MAX_UPLOAD_MB=25`, `TEMP_DIR=./tmp/audio`.
- Endpoints (MVP only): `POST /meetings/upload` (multipart field `audio`) → `202 {id,status}`; `GET /meetings/:id` → `{id,status,knowledge,error}`.
- Allowed audio extensions: `.m4a .mp3 .wav .webm .mp4 .aac`.
- Error envelope: `{"error":{"code":"...","message":"..."}}`.
- All AI adapters take a configurable base URL + `*http.Client` so they are testable against `httptest`.
- Every task ends green (`go test ./...`) and a commit.

---

### Task 1: Project bootstrap, config, health endpoint

**Files:**
- Create: `backend/go.mod` (via `go mod init`)
- Create: `backend/internal/config/config.go`
- Create: `backend/internal/config/config_test.go`
- Create: `backend/cmd/server/main.go`
- Create: `backend/docker-compose.yml`
- Create: `backend/.env.example`
- Create: `backend/.gitignore`

**Interfaces:**
- Consumes: nothing.
- Produces: `config.Config` struct + `config.Load() config.Config`; a runnable server with `GET /health` → `200 {"status":"ok"}`.

- [ ] **Step 1: Initialize module and dependencies**

```bash
cd backend
go mod init meetingmind
go get github.com/gin-gonic/gin@latest
go get github.com/joho/godotenv@latest
```

- [ ] **Step 2: Write the failing config test**

`backend/internal/config/config_test.go`:
```go
package config

import (
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	t.Setenv("OPENAI_API_KEY", "sk-test")
	t.Setenv("DATABASE_URL", "postgres://localhost/db")
	cfg := Load()

	if cfg.Port != "8080" {
		t.Errorf("Port = %q, want 8080", cfg.Port)
	}
	if cfg.STTModel != "whisper-1" {
		t.Errorf("STTModel = %q, want whisper-1", cfg.STTModel)
	}
	if cfg.AnalyzerModel != "gpt-4o-mini" {
		t.Errorf("AnalyzerModel = %q, want gpt-4o-mini", cfg.AnalyzerModel)
	}
	if cfg.MaxUploadMB != 25 {
		t.Errorf("MaxUploadMB = %d, want 25", cfg.MaxUploadMB)
	}
}

func TestLoadOverrides(t *testing.T) {
	t.Setenv("OPENAI_API_KEY", "sk-test")
	t.Setenv("DATABASE_URL", "postgres://localhost/db")
	t.Setenv("PORT", "9090")
	t.Setenv("MAX_UPLOAD_MB", "10")
	cfg := Load()

	if cfg.Port != "9090" {
		t.Errorf("Port = %q, want 9090", cfg.Port)
	}
	if cfg.MaxUploadMB != 10 {
		t.Errorf("MaxUploadMB = %d, want 10", cfg.MaxUploadMB)
	}
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `go test ./internal/config/ -v`
Expected: FAIL (build error — `Load` / `Config` undefined).

- [ ] **Step 4: Implement config**

`backend/internal/config/config.go`:
```go
package config

import (
	"os"
	"strconv"
)

// Config holds all runtime configuration, sourced from environment variables.
type Config struct {
	OpenAIAPIKey  string
	DatabaseURL   string
	STTModel      string
	AnalyzerModel string
	Port          string
	MaxUploadMB   int64
	TempDir       string
}

// Load reads configuration from the environment, applying documented defaults.
func Load() Config {
	return Config{
		OpenAIAPIKey:  os.Getenv("OPENAI_API_KEY"),
		DatabaseURL:   os.Getenv("DATABASE_URL"),
		STTModel:      getenv("STT_MODEL", "whisper-1"),
		AnalyzerModel: getenv("ANALYZER_MODEL", "gpt-4o-mini"),
		Port:          getenv("PORT", "8080"),
		MaxUploadMB:   getenvInt("MAX_UPLOAD_MB", 25),
		TempDir:       getenv("TEMP_DIR", "./tmp/audio"),
	}
}

func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func getenvInt(key string, def int64) int64 {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.ParseInt(v, 10, 64); err == nil {
			return n
		}
	}
	return def
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `go test ./internal/config/ -v`
Expected: PASS.

- [ ] **Step 6: Write main, docker-compose, env example, gitignore**

`backend/cmd/server/main.go`:
```go
package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	"meetingmind/internal/config"
)

func main() {
	_ = godotenv.Load() // ponytail: best-effort local .env; real env wins in prod.
	cfg := config.Load()

	r := gin.Default()
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	log.Printf("listening on :%s", cfg.Port)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}
```

`backend/docker-compose.yml`:
```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_USER: meetingmind
      POSTGRES_PASSWORD: meetingmind
      POSTGRES_DB: meetingmind
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
volumes:
  pgdata:
```

`backend/.env.example`:
```
OPENAI_API_KEY=sk-your-key
DATABASE_URL=postgres://meetingmind:meetingmind@localhost:5432/meetingmind?sslmode=disable
STT_MODEL=whisper-1
ANALYZER_MODEL=gpt-4o-mini
PORT=8080
MAX_UPLOAD_MB=25
TEMP_DIR=./tmp/audio
```

`backend/.gitignore`:
```
/tmp/
.env
```

- [ ] **Step 7: Verify build and full test run**

Run: `go build ./... && go test ./...`
Expected: build succeeds; config tests PASS.

- [ ] **Step 8: Commit**

```bash
git add backend/
git commit -m "feat(backend): bootstrap module, config, health endpoint"
```

---

### Task 2: Domain models and enums

**Files:**
- Create: `backend/internal/models/enums.go`
- Create: `backend/internal/models/enums_test.go`
- Create: `backend/internal/models/knowledge.go`
- Create: `backend/internal/models/meeting.go`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `ProcessingStatus` (`StatusUploaded/Transcribing/Analyzing/Completed/Failed`) with `IsValid() bool`.
  - `Priority`, `Severity`, `MeetingType`, `Stage` (`StageTranscription`, `StageAnalysis`) string enums.
  - `DefaultUserID = "mvp-single-user"`.
  - `MeetingKnowledge` + value types (`Participant`, `Task`, `Decision`, `Reminder`, `PendingItem`, `FollowUpAction`, `Risk`, `Question`) with JSON tags.
  - `Meeting` struct with GORM tags.

- [ ] **Step 1: Write the failing enum test**

`backend/internal/models/enums_test.go`:
```go
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/models/ -v`
Expected: FAIL (undefined identifiers).

- [ ] **Step 3: Implement enums**

`backend/internal/models/enums.go`:
```go
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/models/ -v`
Expected: PASS.

- [ ] **Step 5: Implement knowledge and meeting structs**

`backend/internal/models/knowledge.go`:
```go
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
```

`backend/internal/models/meeting.go`:
```go
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
```

- [ ] **Step 6: Get uuid dependency and verify**

```bash
go get github.com/google/uuid@latest
go build ./... && go test ./internal/models/ -v
```
Expected: build succeeds; tests PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/internal/models/ backend/go.mod backend/go.sum
git commit -m "feat(backend): typed domain models and processing enums"
```

---

### Task 3: Database connection, migration, and repository

**Files:**
- Create: `backend/internal/database/database.go`
- Create: `backend/internal/repositories/meeting_repository.go`
- Create: `backend/internal/repositories/meeting_repository_test.go`

**Interfaces:**
- Consumes: `models.Meeting`, `models.MeetingKnowledge`.
- Produces:
  - `database.Connect(dsn string) (*gorm.DB, error)`, `database.Migrate(db *gorm.DB) error`.
  - `repositories.Repository` interface: `Create(ctx, *models.Meeting) error`, `Get(ctx, uuid.UUID) (*models.Meeting, error)`, `Update(ctx, *models.Meeting) error`; `ErrNotFound`.
  - `repositories.NewMeetingRepository(db *gorm.DB) *MeetingRepository`.

- [ ] **Step 1: Add drivers**

```bash
go get gorm.io/gorm@latest
go get gorm.io/driver/postgres@latest
go get github.com/glebarez/sqlite@latest
```

- [ ] **Step 2: Write the failing repository test**

`backend/internal/repositories/meeting_repository_test.go`:
```go
package repositories

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/glebarez/sqlite"
	"github.com/google/uuid"
	"gorm.io/gorm"

	"meetingmind/internal/models"
)

func newTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	dbPath := filepath.Join(t.TempDir(), "test.db")
	db, err := gorm.Open(sqlite.Open(dbPath), &gorm.Config{})
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	if err := db.AutoMigrate(&models.Meeting{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func TestCreateGetUpdate(t *testing.T) {
	repo := NewMeetingRepository(newTestDB(t))
	ctx := context.Background()

	m := &models.Meeting{ID: uuid.New(), UserID: models.DefaultUserID, Status: models.StatusUploaded}
	if err := repo.Create(ctx, m); err != nil {
		t.Fatalf("create: %v", err)
	}

	got, err := repo.Get(ctx, m.ID)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if got.Status != models.StatusUploaded {
		t.Errorf("status = %q, want uploaded", got.Status)
	}

	got.Status = models.StatusCompleted
	got.Knowledge = &models.MeetingKnowledge{Title: "Sprint Planning", Tasks: []models.Task{{Task: "ship", Priority: models.PriorityHigh}}}
	if err := repo.Update(ctx, got); err != nil {
		t.Fatalf("update: %v", err)
	}

	reloaded, err := repo.Get(ctx, m.ID)
	if err != nil {
		t.Fatalf("reload: %v", err)
	}
	if reloaded.Status != models.StatusCompleted {
		t.Errorf("status = %q, want completed", reloaded.Status)
	}
	if reloaded.Knowledge == nil || reloaded.Knowledge.Title != "Sprint Planning" {
		t.Errorf("knowledge not persisted/round-tripped: %+v", reloaded.Knowledge)
	}
}

func TestGetNotFound(t *testing.T) {
	repo := NewMeetingRepository(newTestDB(t))
	_, err := repo.Get(context.Background(), uuid.New())
	if err != ErrNotFound {
		t.Errorf("err = %v, want ErrNotFound", err)
	}
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `go test ./internal/repositories/ -v`
Expected: FAIL (build error — `NewMeetingRepository` / `ErrNotFound` undefined).

- [ ] **Step 4: Implement database helpers**

`backend/internal/database/database.go`:
```go
package database

import (
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	"meetingmind/internal/models"
)

// Connect opens a GORM connection to PostgreSQL.
func Connect(dsn string) (*gorm.DB, error) {
	return gorm.Open(postgres.Open(dsn), &gorm.Config{})
}

// Migrate creates/updates the schema for all models.
func Migrate(db *gorm.DB) error {
	return db.AutoMigrate(&models.Meeting{})
}
```

- [ ] **Step 5: Implement repository**

`backend/internal/repositories/meeting_repository.go`:
```go
package repositories

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"gorm.io/gorm"

	"meetingmind/internal/models"
)

// ErrNotFound is returned when a meeting id does not exist.
var ErrNotFound = errors.New("meeting not found")

// Repository is the persistence port the service depends on.
type Repository interface {
	Create(ctx context.Context, m *models.Meeting) error
	Get(ctx context.Context, id uuid.UUID) (*models.Meeting, error)
	Update(ctx context.Context, m *models.Meeting) error
}

type MeetingRepository struct {
	db *gorm.DB
}

func NewMeetingRepository(db *gorm.DB) *MeetingRepository {
	return &MeetingRepository{db: db}
}

func (r *MeetingRepository) Create(ctx context.Context, m *models.Meeting) error {
	return r.db.WithContext(ctx).Create(m).Error
}

func (r *MeetingRepository) Get(ctx context.Context, id uuid.UUID) (*models.Meeting, error) {
	var m models.Meeting
	err := r.db.WithContext(ctx).First(&m, "id = ?", id).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &m, nil
}

func (r *MeetingRepository) Update(ctx context.Context, m *models.Meeting) error {
	return r.db.WithContext(ctx).Save(m).Error
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `go test ./internal/repositories/ -v`
Expected: PASS (both tests).

- [ ] **Step 7: Commit**

```bash
git add backend/internal/database/ backend/internal/repositories/ backend/go.mod backend/go.sum
git commit -m "feat(backend): postgres connection, migration, meeting repository"
```

---

### Task 4: Storage abstraction (local filesystem)

**Files:**
- Create: `backend/internal/storage/storage.go`
- Create: `backend/internal/storage/local/local.go`
- Create: `backend/internal/storage/local/local_test.go`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `storage.Storage` interface: `Save(ctx, key string, r io.Reader) error`, `Open(ctx, key string) (io.ReadCloser, error)`, `Delete(ctx, key string) error`.
  - `local.New(dir string) (*Local, error)` returning a `*Local` that implements `storage.Storage`.

- [ ] **Step 1: Write the failing storage test**

`backend/internal/storage/local/local_test.go`:
```go
package local

import (
	"bytes"
	"context"
	"io"
	"testing"
)

func TestSaveOpenDelete(t *testing.T) {
	s, err := New(t.TempDir())
	if err != nil {
		t.Fatalf("new: %v", err)
	}
	ctx := context.Background()

	if err := s.Save(ctx, "abc.m4a", bytes.NewBufferString("audio-bytes")); err != nil {
		t.Fatalf("save: %v", err)
	}

	rc, err := s.Open(ctx, "abc.m4a")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	data, _ := io.ReadAll(rc)
	rc.Close()
	if string(data) != "audio-bytes" {
		t.Errorf("read = %q, want audio-bytes", data)
	}

	if err := s.Delete(ctx, "abc.m4a"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := s.Open(ctx, "abc.m4a"); err == nil {
		t.Error("expected error opening deleted file")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/storage/... -v`
Expected: FAIL (undefined `New`).

- [ ] **Step 3: Implement interface and local adapter**

`backend/internal/storage/storage.go`:
```go
package storage

import (
	"context"
	"io"
)

// Storage abstracts where recorded audio is kept. MVP uses local disk; an
// object-store adapter can drop in behind this interface later.
type Storage interface {
	Save(ctx context.Context, key string, r io.Reader) error
	Open(ctx context.Context, key string) (io.ReadCloser, error)
	Delete(ctx context.Context, key string) error
}
```

`backend/internal/storage/local/local.go`:
```go
package local

import (
	"context"
	"io"
	"os"
	"path/filepath"
)

// Local stores files under a base directory, keyed by filename.
type Local struct {
	dir string
}

func New(dir string) (*Local, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	return &Local{dir: dir}, nil
}

func (l *Local) path(key string) string {
	return filepath.Join(l.dir, filepath.Base(key))
}

func (l *Local) Save(ctx context.Context, key string, r io.Reader) error {
	f, err := os.Create(l.path(key))
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, r)
	return err
}

func (l *Local) Open(ctx context.Context, key string) (io.ReadCloser, error) {
	return os.Open(l.path(key))
}

func (l *Local) Delete(ctx context.Context, key string) error {
	return os.Remove(l.path(key))
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/storage/... -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/internal/storage/
git commit -m "feat(backend): storage abstraction with local filesystem adapter"
```

---

### Task 5: Prompts package

**Files:**
- Create: `backend/internal/ai/prompts/prompts.go`
- Create: `backend/internal/ai/prompts/prompts_test.go`

**Interfaces:**
- Consumes: nothing.
- Produces: `prompts.AnalysisSystemPrompt string`; `prompts.BuildAnalysisUser(transcript string) string`.

- [ ] **Step 1: Write the failing prompts test**

`backend/internal/ai/prompts/prompts_test.go`:
```go
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/ai/prompts/ -v`
Expected: FAIL (undefined identifiers).

- [ ] **Step 3: Implement prompts**

`backend/internal/ai/prompts/prompts.go`:
```go
package prompts

import "fmt"

// AnalysisSystemPrompt instructs the LLM how to extract structured meeting
// knowledge. Provider-specific schema encoding lives in the analyzer adapter;
// this package holds only natural-language instructions.
const AnalysisSystemPrompt = `You are MeetingMind, an assistant that extracts structured knowledge from a meeting transcript.
Analyze the transcript and produce structured information: a concise title, an executive summary, the meeting type, participants, tasks, decisions, reminders, pending items, follow-up actions, risks, clarifying questions the user should ask, and keywords.
Infer reasonable details: if someone is asked to do something, create a task with the responsible person, a short task description, any mentioned deadline, and a priority (low, medium, or high).
When a field is unknown, use an empty string; when a list has no items, use an empty array.
Return only the structured data — no prose, no markdown.`

// BuildAnalysisUser wraps the transcript as the user message.
func BuildAnalysisUser(transcript string) string {
	return fmt.Sprintf("Transcript:\n%s", transcript)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/ai/prompts/ -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/internal/ai/prompts/
git commit -m "feat(backend): analysis prompt templates package"
```

---

### Task 6: Transcriber interface + OpenAI Whisper adapter

**Files:**
- Create: `backend/internal/ai/transcriber/transcriber.go`
- Create: `backend/internal/ai/transcriber/openai/openai.go`
- Create: `backend/internal/ai/transcriber/openai/openai_test.go`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `transcriber.Transcriber` interface: `Transcribe(ctx, audio io.Reader) (string, error)`.
  - `openai.New(apiKey, baseURL, model string) *Client` implementing it. `baseURL` empty → `https://api.openai.com/v1`.

- [ ] **Step 1: Write the failing adapter test**

`backend/internal/ai/transcriber/openai/openai_test.go`:
```go
package openai

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestTranscribe(t *testing.T) {
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/audio/transcriptions") {
			t.Errorf("path = %s", r.URL.Path)
		}
		if r.Header.Get("Authorization") != "Bearer sk-test" {
			t.Errorf("auth = %s", r.Header.Get("Authorization"))
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"text":"hello world"}`))
	}))
	defer ts.Close()

	c := New("sk-test", ts.URL, "whisper-1")
	got, err := c.Transcribe(context.Background(), strings.NewReader("fake-audio"))
	if err != nil {
		t.Fatalf("transcribe: %v", err)
	}
	if got != "hello world" {
		t.Errorf("got %q, want hello world", got)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/ai/transcriber/... -v`
Expected: FAIL (undefined `New`).

- [ ] **Step 3: Implement interface and adapter**

`backend/internal/ai/transcriber/transcriber.go`:
```go
package transcriber

import (
	"context"
	"io"
)

// Transcriber converts audio to text. MVP impl targets OpenAI Whisper.
type Transcriber interface {
	Transcribe(ctx context.Context, audio io.Reader) (string, error)
}
```

`backend/internal/ai/transcriber/openai/openai.go`:
```go
package openai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
)

const defaultBaseURL = "https://api.openai.com/v1"

// Client is an OpenAI Whisper transcriber.
type Client struct {
	apiKey  string
	baseURL string
	model   string
	http    *http.Client
}

func New(apiKey, baseURL, model string) *Client {
	if baseURL == "" {
		baseURL = defaultBaseURL
	}
	return &Client{apiKey: apiKey, baseURL: baseURL, model: model, http: http.DefaultClient}
}

func (c *Client) Transcribe(ctx context.Context, audio io.Reader) (string, error) {
	var body bytes.Buffer
	w := multipart.NewWriter(&body)

	fw, err := w.CreateFormFile("file", "audio")
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(fw, audio); err != nil {
		return "", err
	}
	if err := w.WriteField("model", c.model); err != nil {
		return "", err
	}
	if err := w.Close(); err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/audio/transcriptions", &body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", w.FormDataContentType())

	resp, err := c.http.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("whisper: status %d: %s", resp.StatusCode, string(b))
	}

	var out struct {
		Text string `json:"text"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return "", err
	}
	return out.Text, nil
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/ai/transcriber/... -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/internal/ai/transcriber/
git commit -m "feat(backend): transcriber interface and OpenAI Whisper adapter"
```

---

### Task 7: Analyzer interface + OpenAI adapter (Structured Outputs)

**Files:**
- Create: `backend/internal/ai/analyzer/analyzer.go`
- Create: `backend/internal/ai/analyzer/openai/schema.go`
- Create: `backend/internal/ai/analyzer/openai/openai.go`
- Create: `backend/internal/ai/analyzer/openai/openai_test.go`

**Interfaces:**
- Consumes: `models.MeetingKnowledge`, `prompts.AnalysisSystemPrompt`, `prompts.BuildAnalysisUser`.
- Produces:
  - `analyzer.Analyzer` interface: `Analyze(ctx, transcript string) (*models.MeetingKnowledge, error)`.
  - `openai.New(apiKey, baseURL, model string) *Client` implementing it.

- [ ] **Step 1: Write the failing adapter test**

`backend/internal/ai/analyzer/openai/openai_test.go`:
```go
package openai

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"meetingmind/internal/models"
)

func TestAnalyzeDeserializes(t *testing.T) {
	knowledge := models.MeetingKnowledge{
		Title:       "Standup",
		Summary:     "Daily sync",
		MeetingType: models.MeetingType("standup"),
		Tasks:       []models.Task{{Responsible: "John", Task: "send document", Deadline: "tomorrow", Priority: models.PriorityMedium}},
	}
	content, _ := json.Marshal(knowledge)

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasSuffix(r.URL.Path, "/chat/completions") {
			t.Errorf("path = %s", r.URL.Path)
		}
		resp := map[string]any{
			"choices": []map[string]any{
				{"message": map[string]any{"content": string(content)}},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer ts.Close()

	c := New("sk-test", ts.URL, "gpt-4o-mini")
	got, err := c.Analyze(context.Background(), "John, could you send that document tomorrow?")
	if err != nil {
		t.Fatalf("analyze: %v", err)
	}
	if got.Title != "Standup" {
		t.Errorf("title = %q, want Standup", got.Title)
	}
	if len(got.Tasks) != 1 || got.Tasks[0].Responsible != "John" {
		t.Errorf("tasks not parsed: %+v", got.Tasks)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/ai/analyzer/... -v`
Expected: FAIL (undefined `New`).

- [ ] **Step 3: Implement interface**

`backend/internal/ai/analyzer/analyzer.go`:
```go
package analyzer

import (
	"context"

	"meetingmind/internal/models"
)

// Analyzer turns a transcript into structured meeting knowledge.
type Analyzer interface {
	Analyze(ctx context.Context, transcript string) (*models.MeetingKnowledge, error)
}
```

- [ ] **Step 4: Implement the provider schema**

`backend/internal/ai/analyzer/openai/schema.go`:
```go
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
```

- [ ] **Step 5: Implement the adapter**

`backend/internal/ai/analyzer/openai/openai.go`:
```go
package openai

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"meetingmind/internal/ai/prompts"
	"meetingmind/internal/models"
)

const defaultBaseURL = "https://api.openai.com/v1"

type Client struct {
	apiKey  string
	baseURL string
	model   string
	http    *http.Client
}

func New(apiKey, baseURL, model string) *Client {
	if baseURL == "" {
		baseURL = defaultBaseURL
	}
	return &Client{apiKey: apiKey, baseURL: baseURL, model: model, http: http.DefaultClient}
}

type chatMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

type jsonSchema struct {
	Name   string          `json:"name"`
	Strict bool            `json:"strict"`
	Schema json.RawMessage `json:"schema"`
}

type responseFormat struct {
	Type       string     `json:"type"`
	JSONSchema jsonSchema `json:"json_schema"`
}

type chatRequest struct {
	Model          string         `json:"model"`
	Messages       []chatMessage  `json:"messages"`
	ResponseFormat responseFormat `json:"response_format"`
}

type chatResponse struct {
	Choices []struct {
		Message chatMessage `json:"message"`
	} `json:"choices"`
}

func (c *Client) Analyze(ctx context.Context, transcript string) (*models.MeetingKnowledge, error) {
	reqBody := chatRequest{
		Model: c.model,
		Messages: []chatMessage{
			{Role: "system", Content: prompts.AnalysisSystemPrompt},
			{Role: "user", Content: prompts.BuildAnalysisUser(transcript)},
		},
		ResponseFormat: responseFormat{
			Type: "json_schema",
			JSONSchema: jsonSchema{
				Name:   "meeting_knowledge",
				Strict: true,
				Schema: knowledgeSchema,
			},
		},
	}
	buf, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/chat/completions", bytes.NewReader(buf))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		b, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("analyzer: status %d: %s", resp.StatusCode, string(b))
	}

	var out chatResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, err
	}
	if len(out.Choices) == 0 {
		return nil, fmt.Errorf("analyzer: no choices returned")
	}

	var knowledge models.MeetingKnowledge
	if err := json.Unmarshal([]byte(out.Choices[0].Message.Content), &knowledge); err != nil {
		return nil, fmt.Errorf("analyzer: decode content: %w", err)
	}
	return &knowledge, nil
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `go test ./internal/ai/analyzer/... -v`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/internal/ai/analyzer/
git commit -m "feat(backend): analyzer interface and OpenAI structured-outputs adapter"
```

---

### Task 8: Meeting service (orchestration + lifecycle)

**Files:**
- Create: `backend/internal/services/meeting_service.go`
- Create: `backend/internal/services/meeting_service_test.go`

**Interfaces:**
- Consumes: `repositories.Repository`, `storage.Storage`, `transcriber.Transcriber`, `analyzer.Analyzer`, `models.*`.
- Produces:
  - `services.NewMeetingService(repo, store, tr, an) *MeetingService` (dispatch defaults to `go f()`).
  - `Submit(ctx, filename string, r io.Reader) (*models.Meeting, error)` — stores audio, persists `uploaded`, dispatches processing.
  - `Get(ctx, id uuid.UUID) (*models.Meeting, error)`.
  - Exported field `Dispatch func(func())` so tests can run processing synchronously.

- [ ] **Step 1: Write the failing service test**

`backend/internal/services/meeting_service_test.go`:
```go
package services

import (
	"context"
	"errors"
	"io"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"

	"meetingmind/internal/models"
	"meetingmind/internal/repositories"
)

// --- fakes ---

type memRepo struct {
	mu sync.Mutex
	m  map[uuid.UUID]*models.Meeting
}

func newMemRepo() *memRepo { return &memRepo{m: map[uuid.UUID]*models.Meeting{}} }

func (r *memRepo) Create(_ context.Context, m *models.Meeting) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	cp := *m
	r.m[m.ID] = &cp
	return nil
}
func (r *memRepo) Get(_ context.Context, id uuid.UUID) (*models.Meeting, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	m, ok := r.m[id]
	if !ok {
		return nil, repositories.ErrNotFound
	}
	cp := *m
	return &cp, nil
}
func (r *memRepo) Update(_ context.Context, m *models.Meeting) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	cp := *m
	r.m[m.ID] = &cp
	return nil
}

type fakeStore struct{ deleted bool }

func (s *fakeStore) Save(context.Context, string, io.Reader) error { return nil }
func (s *fakeStore) Open(context.Context, string) (io.ReadCloser, error) {
	return io.NopCloser(strings.NewReader("audio")), nil
}
func (s *fakeStore) Delete(context.Context, string) error { s.deleted = true; return nil }

type fakeTranscriber struct{ err error }

func (f fakeTranscriber) Transcribe(context.Context, io.Reader) (string, error) {
	return "some transcript", f.err
}

type fakeAnalyzer struct{ err error }

func (f fakeAnalyzer) Analyze(context.Context, string) (*models.MeetingKnowledge, error) {
	if f.err != nil {
		return nil, f.err
	}
	return &models.MeetingKnowledge{Title: "Result"}, nil
}

// sync dispatcher for deterministic tests
func syncDispatch(f func()) { f() }

func TestSubmitHappyPath(t *testing.T) {
	repo := newMemRepo()
	store := &fakeStore{}
	svc := NewMeetingService(repo, store, fakeTranscriber{}, fakeAnalyzer{})
	svc.Dispatch = syncDispatch

	m, err := svc.Submit(context.Background(), "rec.m4a", strings.NewReader("audio"))
	if err != nil {
		t.Fatalf("submit: %v", err)
	}

	got, _ := repo.Get(context.Background(), m.ID)
	if got.Status != models.StatusCompleted {
		t.Errorf("status = %q, want completed", got.Status)
	}
	if got.Knowledge == nil || got.Knowledge.Title != "Result" {
		t.Errorf("knowledge = %+v", got.Knowledge)
	}
	if got.Transcript != "some transcript" {
		t.Errorf("transcript = %q", got.Transcript)
	}
	if !store.deleted {
		t.Error("audio not cleaned up")
	}
}

func TestSubmitAnalysisFailure(t *testing.T) {
	repo := newMemRepo()
	svc := NewMeetingService(repo, &fakeStore{}, fakeTranscriber{}, fakeAnalyzer{err: errors.New("boom")})
	svc.Dispatch = syncDispatch

	m, _ := svc.Submit(context.Background(), "rec.m4a", strings.NewReader("audio"))
	got, _ := repo.Get(context.Background(), m.ID)

	if got.Status != models.StatusFailed {
		t.Errorf("status = %q, want failed", got.Status)
	}
	if got.FailedStage == nil || *got.FailedStage != models.StageAnalysis {
		t.Errorf("failed stage = %v, want analysis", got.FailedStage)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/services/ -v`
Expected: FAIL (undefined `NewMeetingService`).

- [ ] **Step 3: Implement the service**

`backend/internal/services/meeting_service.go`:
```go
package services

import (
	"context"
	"io"
	"log"
	"path/filepath"

	"github.com/google/uuid"

	"meetingmind/internal/ai/analyzer"
	"meetingmind/internal/ai/transcriber"
	"meetingmind/internal/models"
	"meetingmind/internal/repositories"
	"meetingmind/internal/storage"
)

// MeetingService orchestrates the transcribe→analyze pipeline and owns the
// processing lifecycle. It depends only on interfaces.
type MeetingService struct {
	repo        repositories.Repository
	storage     storage.Storage
	transcriber transcriber.Transcriber
	analyzer    analyzer.Analyzer

	// Dispatch runs the background pipeline. Defaults to a goroutine; tests
	// override it to run synchronously.
	Dispatch func(func())
}

func NewMeetingService(
	repo repositories.Repository,
	store storage.Storage,
	tr transcriber.Transcriber,
	an analyzer.Analyzer,
) *MeetingService {
	return &MeetingService{
		repo:        repo,
		storage:     store,
		transcriber: tr,
		analyzer:    an,
		Dispatch:    func(f func()) { go f() },
	}
}

// Submit stores the audio, persists a meeting in the uploaded state, and
// dispatches asynchronous processing.
func (s *MeetingService) Submit(ctx context.Context, filename string, r io.Reader) (*models.Meeting, error) {
	id := uuid.New()
	key := id.String() + filepath.Ext(filename)

	if err := s.storage.Save(ctx, key, r); err != nil {
		return nil, err
	}

	m := &models.Meeting{
		ID:       id,
		UserID:   models.DefaultUserID,
		Status:   models.StatusUploaded,
		AudioKey: key,
	}
	if err := s.repo.Create(ctx, m); err != nil {
		return nil, err
	}

	s.Dispatch(func() { s.process(context.Background(), id) })
	return m, nil
}

func (s *MeetingService) Get(ctx context.Context, id uuid.UUID) (*models.Meeting, error) {
	return s.repo.Get(ctx, id)
}

func (s *MeetingService) process(ctx context.Context, id uuid.UUID) {
	m, err := s.repo.Get(ctx, id)
	if err != nil {
		log.Printf("process: load %s: %v", id, err)
		return
	}

	fail := func(stage models.Stage, cause error) {
		m.Status = models.StatusFailed
		m.FailedStage = &stage
		m.ErrorMessage = cause.Error()
		if err := s.repo.Update(ctx, m); err != nil {
			log.Printf("process: persist failure %s: %v", id, err)
		}
		_ = s.storage.Delete(ctx, m.AudioKey)
		log.Printf("process: meeting %s failed at %s: %v", id, stage, cause)
	}

	// Transcription stage.
	m.Status = models.StatusTranscribing
	_ = s.repo.Update(ctx, m)

	audio, err := s.storage.Open(ctx, m.AudioKey)
	if err != nil {
		fail(models.StageTranscription, err)
		return
	}
	transcript, err := s.transcriber.Transcribe(ctx, audio)
	audio.Close()
	if err != nil {
		fail(models.StageTranscription, err)
		return
	}
	m.Transcript = transcript

	// Analysis stage.
	m.Status = models.StatusAnalyzing
	_ = s.repo.Update(ctx, m)

	knowledge, err := s.analyzer.Analyze(ctx, transcript)
	if err != nil {
		fail(models.StageAnalysis, err)
		return
	}
	m.Knowledge = knowledge

	// Completion + cleanup.
	m.Status = models.StatusCompleted
	if err := s.repo.Update(ctx, m); err != nil {
		log.Printf("process: persist completion %s: %v", id, err)
		return
	}
	_ = s.storage.Delete(ctx, m.AudioKey)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `go test ./internal/services/ -v`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add backend/internal/services/
git commit -m "feat(backend): meeting service orchestrating the async pipeline"
```

---

### Task 9: HTTP handlers, DTOs, middleware, and wiring

**Files:**
- Create: `backend/internal/handlers/dto.go`
- Create: `backend/internal/handlers/meeting_handler.go`
- Create: `backend/internal/handlers/meeting_handler_test.go`
- Create: `backend/internal/middleware/middleware.go`
- Modify: `backend/cmd/server/main.go`

**Interfaces:**
- Consumes: `*services.MeetingService`, `models.*`, `repositories.ErrNotFound`.
- Produces:
  - `handlers.NewMeetingHandler(svc *services.MeetingService, maxUploadMB int64, allowedExts []string) *MeetingHandler`.
  - `RegisterRoutes(r gin.IRouter)` binding `POST /meetings/upload` and `GET /meetings/:id`.
  - `middleware.CORS()` gin middleware.

- [ ] **Step 1: Write the failing handler test**

`backend/internal/handlers/meeting_handler_test.go`:
```go
package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"mime/multipart"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"meetingmind/internal/models"
	"meetingmind/internal/services"
)

// fakes reused via minimal in-package stubs
type memRepo struct{ m map[uuid.UUID]*models.Meeting }

func (r *memRepo) Create(_ context.Context, m *models.Meeting) error { r.m[m.ID] = m; return nil }
func (r *memRepo) Get(_ context.Context, id uuid.UUID) (*models.Meeting, error) {
	if v, ok := r.m[id]; ok {
		return v, nil
	}
	return nil, gormNotFound
}
func (r *memRepo) Update(_ context.Context, m *models.Meeting) error { r.m[m.ID] = m; return nil }

type nopStore struct{}

func (nopStore) Save(context.Context, string, io.Reader) error { return nil }
func (nopStore) Open(context.Context, string) (io.ReadCloser, error) {
	return io.NopCloser(strings.NewReader("a")), nil
}
func (nopStore) Delete(context.Context, string) error { return nil }

type nopTranscriber struct{}

func (nopTranscriber) Transcribe(context.Context, io.Reader) (string, error) { return "t", nil }

type nopAnalyzer struct{}

func (nopAnalyzer) Analyze(context.Context, string) (*models.MeetingKnowledge, error) {
	return &models.MeetingKnowledge{Title: "T"}, nil
}

func newHandler() *MeetingHandler {
	repo := &memRepo{m: map[uuid.UUID]*models.Meeting{}}
	svc := services.NewMeetingService(repo, nopStore{}, nopTranscriber{}, nopAnalyzer{})
	svc.Dispatch = func(f func()) {} // don't run pipeline in handler tests
	return NewMeetingHandler(svc, 25, []string{".m4a", ".mp3"})
}

func TestUploadMissingFile(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	newHandler().RegisterRoutes(r)

	req := httptest.NewRequest(http.MethodPost, "/meetings/upload", nil)
	req.Header.Set("Content-Type", "multipart/form-data; boundary=x")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("code = %d, want 400", w.Code)
	}
}

func TestUploadAcceptedReturns202(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	newHandler().RegisterRoutes(r)

	var body bytes.Buffer
	mw := multipart.NewWriter(&body)
	fw, _ := mw.CreateFormFile("audio", "rec.m4a")
	fw.Write([]byte("audio-bytes"))
	mw.Close()

	req := httptest.NewRequest(http.MethodPost, "/meetings/upload", &body)
	req.Header.Set("Content-Type", mw.FormDataContentType())
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusAccepted {
		t.Fatalf("code = %d, want 202 (body: %s)", w.Code, w.Body.String())
	}
	var resp map[string]any
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp["status"] != "uploaded" {
		t.Errorf("status = %v, want uploaded", resp["status"])
	}
}
```

Note: `gormNotFound` in the stub aliases the repository's not-found error so the handler's 404 mapping is exercised in future tests. Define it in the test file:
```go
var gormNotFound = repositories.ErrNotFound
```
Add the import `"meetingmind/internal/repositories"` to the test file's import block.

- [ ] **Step 2: Run test to verify it fails**

Run: `go test ./internal/handlers/ -v`
Expected: FAIL (undefined `NewMeetingHandler`).

- [ ] **Step 3: Implement DTOs**

`backend/internal/handlers/dto.go`:
```go
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
```

- [ ] **Step 4: Implement the handler**

`backend/internal/handlers/meeting_handler.go`:
```go
package handlers

import (
	"errors"
	"net/http"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"meetingmind/internal/repositories"
	"meetingmind/internal/services"
)

type MeetingHandler struct {
	svc         *services.MeetingService
	maxUploadMB int64
	allowedExts map[string]bool
}

func NewMeetingHandler(svc *services.MeetingService, maxUploadMB int64, allowedExts []string) *MeetingHandler {
	set := make(map[string]bool, len(allowedExts))
	for _, e := range allowedExts {
		set[strings.ToLower(e)] = true
	}
	return &MeetingHandler{svc: svc, maxUploadMB: maxUploadMB, allowedExts: set}
}

func (h *MeetingHandler) RegisterRoutes(r gin.IRouter) {
	r.POST("/meetings/upload", h.upload)
	r.GET("/meetings/:id", h.get)
}

func (h *MeetingHandler) upload(c *gin.Context) {
	fileHeader, err := c.FormFile("audio")
	if err != nil {
		c.JSON(http.StatusBadRequest, errorEnvelope("validation_error", "missing audio file"))
		return
	}
	if fileHeader.Size > h.maxUploadMB*1024*1024 {
		c.JSON(http.StatusBadRequest, errorEnvelope("validation_error", "file too large"))
		return
	}
	ext := strings.ToLower(filepath.Ext(fileHeader.Filename))
	if !h.allowedExts[ext] {
		c.JSON(http.StatusBadRequest, errorEnvelope("validation_error", "unsupported audio format"))
		return
	}

	f, err := fileHeader.Open()
	if err != nil {
		c.JSON(http.StatusBadRequest, errorEnvelope("validation_error", "cannot read upload"))
		return
	}
	defer f.Close()

	m, err := h.svc.Submit(c.Request.Context(), fileHeader.Filename, f)
	if err != nil {
		c.JSON(http.StatusInternalServerError, errorEnvelope("internal_error", "failed to accept upload"))
		return
	}

	c.JSON(http.StatusAccepted, gin.H{"id": m.ID.String(), "status": m.Status})
}

func (h *MeetingHandler) get(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, errorEnvelope("validation_error", "invalid meeting id"))
		return
	}
	m, err := h.svc.Get(c.Request.Context(), id)
	if errors.Is(err, repositories.ErrNotFound) {
		c.JSON(http.StatusNotFound, errorEnvelope("not_found", "meeting not found"))
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, errorEnvelope("internal_error", "failed to load meeting"))
		return
	}
	c.JSON(http.StatusOK, toMeetingResponse(m))
}
```

- [ ] **Step 5: Implement middleware**

`backend/internal/middleware/middleware.go`:
```go
package middleware

import "github.com/gin-gonic/gin"

// CORS is a permissive CORS middleware suitable for local mobile development.
// ponytail: wide-open origins for the MVP; lock down before any public deploy.
func CORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `go test ./internal/handlers/ -v`
Expected: PASS (both tests).

- [ ] **Step 7: Wire everything in main**

Replace `backend/cmd/server/main.go`:
```go
package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	analyzeropenai "meetingmind/internal/ai/analyzer/openai"
	transcriberopenai "meetingmind/internal/ai/transcriber/openai"
	"meetingmind/internal/config"
	"meetingmind/internal/database"
	"meetingmind/internal/handlers"
	"meetingmind/internal/middleware"
	"meetingmind/internal/repositories"
	"meetingmind/internal/services"
	"meetingmind/internal/storage/local"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	db, err := database.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("db connect: %v", err)
	}
	if err := database.Migrate(db); err != nil {
		log.Fatalf("db migrate: %v", err)
	}

	store, err := local.New(cfg.TempDir)
	if err != nil {
		log.Fatalf("storage: %v", err)
	}

	repo := repositories.NewMeetingRepository(db)
	tr := transcriberopenai.New(cfg.OpenAIAPIKey, "", cfg.STTModel)
	an := analyzeropenai.New(cfg.OpenAIAPIKey, "", cfg.AnalyzerModel)
	svc := services.NewMeetingService(repo, store, tr, an)

	allowed := []string{".m4a", ".mp3", ".wav", ".webm", ".mp4", ".aac"}
	h := handlers.NewMeetingHandler(svc, cfg.MaxUploadMB, allowed)

	r := gin.Default()
	r.Use(middleware.CORS())
	r.GET("/health", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
	h.RegisterRoutes(r)

	log.Printf("listening on :%s", cfg.Port)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}
```

- [ ] **Step 8: Verify full build and test suite**

Run: `go build ./... && go test ./...`
Expected: build succeeds; all packages PASS.

- [ ] **Step 9: Commit**

```bash
git add backend/
git commit -m "feat(backend): HTTP handlers, DTOs, CORS, and full wiring"
```

---

## Manual End-to-End Verification (after Task 9)

Not automated (needs a real OpenAI key + DB). Run once to confirm the slice:

```bash
cd backend
cp .env.example .env         # fill in OPENAI_API_KEY
docker compose up -d db
go run ./cmd/server
# in another shell:
curl -F "audio=@sample.m4a" http://localhost:8080/meetings/upload
# → {"id":"<uuid>","status":"uploaded"}
curl http://localhost:8080/meetings/<uuid>
# poll until {"status":"completed","knowledge":{...}}
```

---

## Self-Review

**Spec coverage:**
- Async pipeline + typed lifecycle → Tasks 2, 8. ✓
- `Transcriber` / `Analyzer` / `Storage` / `Repository` interfaces → Tasks 3, 4, 6, 7. ✓
- Full `MeetingKnowledge` schema (participants…keywords, meeting_type) → Tasks 2, 7 (schema). ✓
- Structured Outputs (json_schema, strict) → Task 7. ✓
- jsonb persistence of typed knowledge → Tasks 2 (tag), 3 (round-trip test). ✓
- Endpoints + error envelope + validation (size/format) → Task 9. ✓
- Config via env with documented defaults → Task 1. ✓
- Constant user id, no auth → Task 2 (`DefaultUserID`), used in Task 8. ✓
- docker-compose Postgres, .env.example → Task 1. ✓
- Testing strategy (service lifecycle w/ fakes, analyzer decode, upload validation) → Tasks 8, 7, 9. ✓
- Deferred items (auth/list/delete/reprocess) correctly absent. ✓

**Placeholder scan:** none — every code/test step contains complete content; the only non-automated piece (real-API E2E) is explicitly isolated in the manual section.

**Type consistency:** `Submit`/`Get`/`process`, `Dispatch func(func())`, `repositories.Repository` (Create/Get/Update), `storage.Storage` (Save/Open/Delete), `transcriber.Transcribe`, `analyzer.Analyze`, `models.MeetingKnowledge` + value types, and enum constants are referenced identically across Tasks 2–9. The service constructor signature `NewMeetingService(repo, store, tr, an)` matches its callers in Tasks 8 and 9. ✓
