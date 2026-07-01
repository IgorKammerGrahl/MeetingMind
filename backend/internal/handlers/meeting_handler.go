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
