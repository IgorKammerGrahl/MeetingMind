package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	analyzeropenai "meetingmind/internal/ai/analyzer/openai"
	transcriberopenai "meetingmind/internal/ai/transcriber/openai"
	"meetingmind/internal/config"
	"meetingmind/internal/database"
	"meetingmind/internal/discovery"
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
	tr := transcriberopenai.New(cfg.OpenAIAPIKey, cfg.OpenAIBaseURL, cfg.STTModel)
	an := analyzeropenai.New(cfg.OpenAIAPIKey, cfg.OpenAIBaseURL, cfg.AnalyzerModel)
	svc := services.NewMeetingService(repo, store, tr, an)

	allowed := []string{".m4a", ".mp3", ".wav", ".webm", ".mp4", ".aac"}
	h := handlers.NewMeetingHandler(svc, cfg.MaxUploadMB, allowed)

	r := gin.Default()
	r.Use(middleware.CORS())
	r.GET("/health", func(c *gin.Context) { c.JSON(200, gin.H{"status": "ok"}) })
	h.RegisterRoutes(r)

	go discovery.Serve(cfg.Port)

	log.Printf("listening on :%s", cfg.Port)
	if err := r.Run(":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}
