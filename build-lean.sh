#!/bin/sh
# Builds the lean sing-box-extended binary for OpenWrt routers running Forkop.
# Usage: sh build-lean.sh [GOARCH]   (default arm64; output: dist/sing-box-lean-linux-$GOARCH)
set -e
cd "$(dirname "$0")"

ARCH=${1:-arm64}
BASE_VERSION=$(git describe --tags --abbrev=0 --match 'v*-extended-*' --exclude '*-lean' | sed 's/^v//')
VERSION="$BASE_VERSION+lean"
# vless/vmess/trojan/shadowsocks/socks/http and ws/grpc/httpupgrade/xhttp are always built in.
# with_quic: hysteria2 + xhttp h3; with_utls: reality + fingerprints; with_clash_api: Forkop dashboard.
# lean: protocol registry trimmed to what Forkop generates; lean_memlimit: 64 MiB soft heap limit.
TAGS=with_quic,with_utls,with_clash_api,lean,lean_memlimit,badlinkname,tfogo_checklinkname0
OUT=dist/sing-box-lean-linux-$ARCH

mkdir -p dist
GOOS=linux GOARCH=$ARCH CGO_ENABLED=0 go build -trimpath -tags "$TAGS" \
    -ldflags "-X 'github.com/sagernet/sing-box/constant.Version=$VERSION' $(cat release/LDFLAGS) -s -w -buildid=" \
    -o "$OUT" ./cmd/sing-box
(cd dist && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256")
ls -l "$OUT"
cat "$OUT.sha256"
