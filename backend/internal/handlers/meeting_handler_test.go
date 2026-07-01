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
	"meetingmind/internal/repositories"
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

var gormNotFound = repositories.ErrNotFound

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
