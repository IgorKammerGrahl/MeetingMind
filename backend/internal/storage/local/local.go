package local

import (
	"context"
	"io"
	"os"
	"path/filepath"
)

// Local stores files under a base directory, keyed by filename.
type Local struct {
	dir string
}

func New(dir string) (*Local, error) {
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return nil, err
	}
	return &Local{dir: dir}, nil
}

func (l *Local) path(key string) string {
	return filepath.Join(l.dir, filepath.Base(key))
}

func (l *Local) Save(ctx context.Context, key string, r io.Reader) error {
	f, err := os.Create(l.path(key))
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, r)
	return err
}

func (l *Local) Open(ctx context.Context, key string) (io.ReadCloser, error) {
	return os.Open(l.path(key))
}

func (l *Local) Delete(ctx context.Context, key string) error {
	return os.Remove(l.path(key))
}
