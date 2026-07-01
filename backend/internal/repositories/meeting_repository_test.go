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
