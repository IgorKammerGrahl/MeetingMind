package local

import (
	"bytes"
	"context"
	"io"
	"testing"
)

func TestSaveOpenDelete(t *testing.T) {
	s, err := New(t.TempDir())
	if err != nil {
		t.Fatalf("new: %v", err)
	}
	ctx := context.Background()

	if err := s.Save(ctx, "abc.m4a", bytes.NewBufferString("audio-bytes")); err != nil {
		t.Fatalf("save: %v", err)
	}

	rc, err := s.Open(ctx, "abc.m4a")
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	data, _ := io.ReadAll(rc)
	rc.Close()
	if string(data) != "audio-bytes" {
		t.Errorf("read = %q, want audio-bytes", data)
	}

	if err := s.Delete(ctx, "abc.m4a"); err != nil {
		t.Fatalf("delete: %v", err)
	}
	if _, err := s.Open(ctx, "abc.m4a"); err == nil {
		t.Error("expected error opening deleted file")
	}
}
