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

// List returns all meetings, newest first.
func (s *MeetingService) List(ctx context.Context) ([]models.Meeting, error) {
	return s.repo.List(ctx)
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
