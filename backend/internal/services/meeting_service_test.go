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
