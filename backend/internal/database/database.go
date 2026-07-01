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
