package transcriber

import (
	"context"
	"io"
)

// Transcriber converts audio to text. MVP impl targets OpenAI Whisper.
type Transcriber interface {
	Transcribe(ctx context.Context, audio io.Reader) (string, error)
}
