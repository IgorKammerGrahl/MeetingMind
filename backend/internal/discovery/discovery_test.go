package discovery

import (
	"net"
	"testing"
	"time"
)

func TestServeRepliesWithPort(t *testing.T) {
	go Serve("9999")
	time.Sleep(50 * time.Millisecond) // let the listener bind

	conn, err := net.Dial("udp", "127.0.0.1:41234")
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	if _, err := conn.Write([]byte(probe)); err != nil {
		t.Fatalf("write probe: %v", err)
	}

	_ = conn.SetReadDeadline(time.Now().Add(time.Second))
	buf := make([]byte, 64)
	n, err := conn.Read(buf)
	if err != nil {
		t.Fatalf("read reply: %v", err)
	}

	got := string(buf[:n])
	want := replyPrefix + "9999"
	if got != want {
		t.Errorf("reply = %q, want %q", got, want)
	}
}

func TestServeIgnoresUnknownMessages(t *testing.T) {
	conn, err := net.Dial("udp", "127.0.0.1:41234")
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	if _, err := conn.Write([]byte("not a probe")); err != nil {
		t.Fatalf("write: %v", err)
	}

	_ = conn.SetReadDeadline(time.Now().Add(200 * time.Millisecond))
	buf := make([]byte, 64)
	if _, err := conn.Read(buf); err == nil {
		t.Error("expected no reply to an unrecognized message")
	}
}
