#!/bin/bash
# Loopback test of a lean sing-box binary: runs a server and a client from the same binary
# and pushes 20 MB through every transport the router uses (XHTTP, Reality, gRPC, TLS,
# Hysteria2, Vision), then checks a Forkop-shaped config. Needs python3 and curl.
# Usage: bash lean/e2e/run.sh <sing-box binary for this machine>
set -u
BIN=$(realpath "$1")
DIR=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$WORK"' EXIT
fail() { echo "E2E FAIL: $*"; echo "--- server log"; tail -20 "$WORK/server.log"; echo "--- client log"; tail -20 "$WORK/client.log"; exit 1; }

version=$("$BIN" version | head -1)
echo "$version"
case "$version" in *extended*+lean*) ;; *) fail "unexpected version line: $version" ;; esac

{ "$BIN" generate reality-keypair; "$BIN" generate uuid; "$BIN" generate tls-keypair test.local; } > "$WORK/gen.txt"
python3 "$DIR/make_configs.py" "$WORK/gen.txt" "$WORK" || fail "config generation"
for c in server client forkop; do
    "$BIN" check -c "$WORK/$c.json" 2>"$WORK/check-$c.log" || { cat "$WORK/check-$c.log"; fail "check $c.json"; }
done
echo "check: server, client, forkop-shaped configs ok"

mkdir -p "$WORK/www"
head -c 1024 /dev/urandom > "$WORK/www/small"
head -c 20000000 /dev/urandom > "$WORK/www/big"
(cd "$WORK/www" && exec python3 -m http.server 8080 --bind 127.0.0.1 >/dev/null 2>&1) &
"$BIN" run -c "$WORK/server.json" >"$WORK/server.log" 2>&1 &
"$BIN" run -c "$WORK/client.json" -D "$WORK" >"$WORK/client.log" 2>&1 &
sleep 4

port=30001
for name in xhttp-reality xhttp-tls grpc-reality tls hy2 reality-vision; do
    result=$(curl -s -o /dev/null -w '%{http_code} %{size_download}' --max-time 90 \
        -x "socks5h://127.0.0.1:$port" http://127.0.0.1:8080/big)
    echo "$name: $result"
    [ "$result" = "200 20000000" ] || fail "$name transfer"
    port=$((port + 1))
done

curl -s --max-time 15 http://127.0.0.1:9090/proxies/auto | grep -q '"now"' || fail "clash api / urltest"
echo "clash api: ok"
echo "E2E OK"
