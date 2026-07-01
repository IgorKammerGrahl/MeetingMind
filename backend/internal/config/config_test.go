package config

import (
	"os"
	"testing"
)

func TestLoadConfig(t *testing.T) {
	os.Setenv("OPENAI_API_KEY", "test-key")
	os.Setenv("DATABASE_URL", "postgres://localhost/test")
	os.Setenv("STT_MODEL", "whisper-1")
	os.Setenv("ANALYZER_MODEL", "gpt-4o-mini")
	os.Setenv("PORT", "8080")
	os.Setenv("MAX_UPLOAD_MB", "25")
	os.Setenv("TEMP_DIR", "./tmp/audio")

	cfg := Load()

	if cfg.OpenAIAPIKey != "test-key" {
		t.Errorf("OpenAIAPIKey mismatch: got %s, want test-key", cfg.OpenAIAPIKey)
	}
	if cfg.DatabaseURL != "postgres://localhost/test" {
		t.Errorf("DatabaseURL mismatch: got %s, want postgres://localhost/test", cfg.DatabaseURL)
	}
	if cfg.STTModel != "whisper-1" {
		t.Errorf("STTModel mismatch: got %s, want whisper-1", cfg.STTModel)
	}
	if cfg.AnalyzerModel != "gpt-4o-mini" {
		t.Errorf("AnalyzerModel mismatch: got %s, want gpt-4o-mini", cfg.AnalyzerModel)
	}
	if cfg.Port != "8080" {
		t.Errorf("Port mismatch: got %s, want 8080", cfg.Port)
	}
	if cfg.MaxUploadMB != 25 {
		t.Errorf("MaxUploadMB mismatch: got %d, want 25", cfg.MaxUploadMB)
	}
	if cfg.TempDir != "./tmp/audio" {
		t.Errorf("TempDir mismatch: got %s, want ./tmp/audio", cfg.TempDir)
	}
}
