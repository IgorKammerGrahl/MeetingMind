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
	List(ctx context.Context) ([]models.Meeting, error)
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

// List returns all meetings, newest first.
func (r *MeetingRepository) List(ctx context.Context) ([]models.Meeting, error) {
	var ms []models.Meeting
	err := r.db.WithContext(ctx).Order("created_at DESC").Find(&ms).Error
	return ms, err
}
