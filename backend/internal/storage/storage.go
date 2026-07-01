package storage

import (
	"context"
	"io"
)

// Storage abstracts where recorded audio is kept. MVP uses local disk; an
// object-store adapter can drop in behind this interface later.
type Storage interface {
	Save(ctx context.Context, key string, r io.Reader) error
	Open(ctx context.Context, key string) (io.ReadCloser, error)
	Delete(ctx context.Context, key string) error
}
