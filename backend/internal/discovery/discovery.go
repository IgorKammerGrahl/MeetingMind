// Package discovery lets the mobile app find this backend on the LAN without
// a hardcoded IP: the app broadcasts a probe, this listener replies with the
// real HTTP port. Best-effort only — client-isolated networks (e.g. some
// corporate/campus wifi) block broadcast and the app falls back to its
// configured default.
package discovery

import (
	"log"
	"net"
)

const (
	// Port is fixed so both sides agree on it without configuration.
	Port = 41234

	probe       = "MEETINGMIND_DISCOVER"
	replyPrefix = "MEETINGMIND:"
)

// Serve blocks, replying to discovery probes with httpPort. Call it in a
// goroutine. Disables itself (logs and returns) if the port can't be bound.
func Serve(httpPort string) {
	conn, err := net.ListenUDP("udp", &net.UDPAddr{Port: Port})
	if err != nil {
		log.Printf("discovery: disabled (%v)", err)
		return
	}
	defer conn.Close()

	buf := make([]byte, 64)
	for {
		n, remote, err := conn.ReadFromUDP(buf)
		if err != nil {
			continue
		}
		if string(buf[:n]) != probe {
			continue
		}
		_, _ = conn.WriteToUDP([]byte(replyPrefix+httpPort), remote)
	}
}
