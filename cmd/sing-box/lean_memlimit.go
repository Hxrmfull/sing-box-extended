//go:build lean_memlimit

package main

import (
	"os"
	"runtime/debug"
)

// Router builds: keep the Go heap small by default.
// GOMEMLIMIT / GOGC from the environment still take precedence.
func init() {
	if os.Getenv("GOMEMLIMIT") == "" {
		debug.SetMemoryLimit(64 << 20)
	}
	if os.Getenv("GOGC") == "" {
		debug.SetGCPercent(50)
	}
}
