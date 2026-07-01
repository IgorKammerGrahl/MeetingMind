package config

import (
	"os"
	"strconv"
)

type Config struct {
	OpenAIAPIKey  string
	DatabaseURL   string
	STTModel      string
	AnalyzerModel string
	Port          string
	MaxUploadMB   int64
	TempDir       string
}

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

func getenv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getenvInt(key string, defaultValue int64) int64 {
	if value := os.Getenv(key); value != "" {
		if intVal, err := strconv.ParseInt(value, 10, 64); err == nil {
			return intVal
		}
	}
	return defaultValue
}
