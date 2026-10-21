#!/bin/sh
# Installs the lean sing-box-extended build for Forkop on OpenWrt (aarch64):
#   sh <(wget -O - https://raw.githubusercontent.com/Hxrmfull/sing-box-extended/lean/install-lean.sh)
# If /tmp/sing-box already exists (copied by hand), that file is used instead of a download.
#
# Forkop treats the result like its "extended compressed" variant: a standalone binary in
# /usr/bin/sing-box with the init script that Forkop itself manages. Forkop settings
# (/etc/config/forkop) are not touched.
#
# Nothing on the router changes until the preflight passes. After that, any failure puts the
# previous sing-box back from a copy kept in /tmp, so rollback works without internet.

REPO=${LEAN_REPO:-Hxrmfull/sing-box-extended}
ASSET=sing-box-lean-linux-arm64
WORK=/tmp/sing-box-lean
NEW=$WORK/sing-box
BACKUP=$WORK/rollback
TARGET=/usr/bin/sing-box
STAGED=/usr/bin/sing-box.lean-new
MARKER=/etc/forkop/sing-box-variant
VERSION_STATE=/etc/forkop/sing-box-version
FAKEIP_TEST_DOMAIN=fakeip.podkop.fyi
DNS_INBOUND=127.0.0.42

say() { echo "[lean] $*"; }
die() { echo "[lean] ERROR: $*" >&2; rm -rf "$WORK"; exit 1; }

pkg_installed() { apk info -e "$1" >/dev/null 2>&1; }
file_kb() { [ -f "$1" ] && echo $(( ($(wc -c < "$1") + 1023) / 1024 )) || echo 0; }
tmp_free_kb() { df -k /tmp | awk 'NR==2 {print $4}'; }

# fetch URL OUT [PROXY]: gives up on a stalled connection after 30s, two tries.
fetch() {
    n=0
    while [ $n -lt 2 ]; do
        if [ -n "$3" ]; then
            http_proxy="http://$3" https_proxy="http://$3" wget -q -T 30 -O "$2" "$1" && return 0
        else
            wget -q -T 30 -O "$2" "$1" && return 0
        fi
        n=$((n + 1))
    done
    return 1
}

# try_source NAME BASE_URL [PROXY]: downloads the binary (gzip when possible) and its
# checksum from one source; succeeds only if the checksum matches.
try_source() {
    say "trying $1"
    rm -f "$NEW" "$NEW.gz" "$NEW.sha256"
    fetch "$2/$ASSET.sha256" "$NEW.sha256" "$3" || { say "  not reachable"; return 1; }
    if [ $HAVE_GUNZIP = 1 ]; then
        fetch "$2/$ASSET.gz" "$NEW.gz" "$3" && gunzip -c "$NEW.gz" > "$NEW" 2>/dev/null
        rm -f "$NEW.gz"
    else
        fetch "$2/$ASSET" "$NEW" "$3"
    fi
    expected=$(awk '{print $1}' "$NEW.sha256")
    actual=$(sha256sum "$NEW" 2>/dev/null | awk '{print $1}')
    if [ -n "$expected" ] && [ "$expected" = "$actual" ]; then
        say "  checksum ok"
        return 0
    fi
    say "  download incomplete or damaged"
    return 1
}

write_or_remove() {
    if [ -n "$2" ]; then echo "$2" > "$1"; else rm -f "$1"; fi
}

restore_previous() {
    # Forkop stop restores dnsmasq and removes its nft rules, so plain internet works
    # while the previous sing-box is being put back.
    /etc/init.d/forkop stop >/dev/null 2>&1
    rm -f "$STAGED" "$TARGET"
    grep -q "Forkop managed sing-box service" /etc/init.d/sing-box 2>/dev/null && rm -f /etc/init.d/sing-box

    restored=0
    if [ -n "$PREV_PKGS" ]; then
        if ls "$BACKUP"/*.apk >/dev/null 2>&1 && apk add --allow-untrusted "$BACKUP"/*.apk </dev/null; then
            restored=1
        elif apk update >/dev/null 2>&1 && apk add $PREV_PKGS </dev/null; then
            restored=1
        fi
    fi
    if [ $restored = 0 ] && [ -f "$BACKUP/sing-box" ]; then
        cp "$BACKUP/sing-box" "$TARGET" && chmod 0755 "$TARGET" && restored=1
    fi

    write_or_remove "$MARKER" "$PREV_MARKER"
    write_or_remove "$VERSION_STATE" "$PREV_VERSION"
    /etc/init.d/forkop start
    if [ $restored = 1 ]; then
        say "previous sing-box ($PREV_VERSION_SHOWN) is back"
    else
        say "could not put the previous sing-box back: install Stable in Forkop -> Components"
    fi
}

rollback() {
    say "problem: $1"
    say "rolling back"
    restore_previous
    die "$1"
}

# Waits until sing-box runs with a stable PID and answers Forkop's FakeIP test query.
sing_box_healthy() {
    i=0
    while [ $i -lt 60 ]; do
        pidof sing-box >/dev/null 2>&1 && break
        sleep 1
        i=$((i + 1))
    done
    pid1=$(pidof sing-box)
    [ -n "$pid1" ] || { say "sing-box is not running"; return 1; }
    sleep 5
    pid2=$(pidof sing-box)
    [ "$pid1" = "$pid2" ] || { say "sing-box keeps restarting"; return 1; }

    i=0
    while [ $i -lt 30 ]; do
        nslookup "$FAKEIP_TEST_DOMAIN" "$DNS_INBOUND" 2>/dev/null | grep -q "198\.1[89]\." && return 0
        sleep 1
        i=$((i + 1))
    done
    say "sing-box does not answer DNS on $DNS_INBOUND"
    return 1
}

# 1. Preflight: nothing is changed until all of these pass.
[ "$(uname -m)" = aarch64 ] || die "this build is for aarch64, router reports $(uname -m)"
[ -x /etc/init.d/forkop ] || die "Forkop is not installed"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum is missing"

rm -rf "$WORK"
mkdir -p "$BACKUP"
if [ -f /tmp/sing-box ]; then
    say "using /tmp/sing-box copied by hand"
    mv /tmp/sing-box "$NEW"
else
    command -v gunzip >/dev/null 2>&1 && HAVE_GUNZIP=1 || HAVE_GUNZIP=0
    release="https://github.com/$REPO/releases/latest/download"
    # raw.githubusercontent.com serves this script too, so it is the source most likely to work.
    # The Forkop proxy ports exist when "download via proxy" is enabled in Forkop settings.
    try_source "GitHub (raw, dist branch)" "https://raw.githubusercontent.com/$REPO/dist" ||
        try_source "GitHub releases" "$release" ||
        try_source "GitHub releases via Forkop proxy :4535" "$release" 127.0.0.1:4535 ||
        try_source "GitHub releases via Forkop proxy :4534" "$release" 127.0.0.1:4534 ||
        try_source "jsDelivr CDN" "https://cdn.jsdelivr.net/gh/$REPO@dist" ||
        die "could not download the lean build from any source, nothing changed.
  Download $ASSET from https://github.com/$REPO/releases on a PC,
  copy it to the router as /tmp/sing-box and run this script again"
fi
chmod 0755 "$NEW"
VER=$("$NEW" version 2>/dev/null | head -1 | awk '{print $NF}')
case "$VER" in
    *extended*lean*) ;;
    *) die "downloaded file does not look like the lean build (version: '$VER')" ;;
esac
say "new sing-box: $VER"

CONFIG=$(uci -q get forkop.settings.config_path)
[ -n "$CONFIG" ] || CONFIG=/etc/sing-box/config.json
if [ -f "$CONFIG" ]; then
    "$NEW" -c "$CONFIG" check || die "current Forkop config does not pass 'check' with the lean build, nothing changed"
    say "current Forkop config passes check"
else
    say "no generated config at $CONFIG yet, skipping config check"
fi

PREV_MARKER=$(cat "$MARKER" 2>/dev/null)
PREV_VERSION=$(cat "$VERSION_STATE" 2>/dev/null)
PREV_VERSION_SHOWN=$("$TARGET" version 2>/dev/null | head -1 | awk '{print $NF}')
PREV_PKGS=""
for pkg in sing-box sing-box-tiny sing-box-extended; do
    pkg_installed "$pkg" && PREV_PKGS="$PREV_PKGS $pkg"
done
say "current sing-box: ${PREV_VERSION_SHOWN:-none}${PREV_PKGS:+ (package:$PREV_PKGS)}"

# Keep a copy of the current sing-box in /tmp for an offline rollback: the package file
# when it comes from the feed, otherwise the binary itself.
if [ -n "$PREV_PKGS" ]; then
    # The package index is not kept across reboots, so refresh it before fetching.
    apk update </dev/null >/dev/null 2>&1
    apk fetch -o "$BACKUP" $PREV_PKGS </dev/null >/dev/null 2>&1 ||
        say "could not cache the package, keeping a copy of the binary instead"
fi
if ! ls "$BACKUP"/*.apk >/dev/null 2>&1 && [ -f "$TARGET" ]; then
    [ "$(tmp_free_kb)" -gt $(( $(file_kb "$TARGET") + 16384 )) ] ||
        die "not enough free RAM in /tmp to keep a rollback copy, nothing changed"
    cp "$TARGET" "$BACKUP/sing-box" || die "could not back up $TARGET, nothing changed"
fi

say "before:"
free -m | sed -n 1,2p
df -h /overlay | tail -1

# 2. Stage the binary on flash first, so a full overlay fails before anything is removed.
rm -f "$STAGED"
if ! cp "$NEW" "$STAGED" 2>/dev/null; then
    rm -f "$STAGED"
    die "not enough space on /overlay for the new binary, nothing changed"
fi
chmod 0755 "$STAGED"

# 3. Swap: stop Forkop, drop packaged sing-box variants, put the lean binary in place.
/etc/init.d/forkop stop
for pkg in $PREV_PKGS; do
    say "removing package $pkg"
    apk del --force-broken-world "$pkg" </dev/null || rollback "failed to remove $pkg"
done
rm -f "$TARGET"
mv "$STAGED" "$TARGET" || rollback "failed to move the binary into $TARGET"
chmod 0755 "$TARGET"

mkdir -p /etc/forkop
echo "extended-compressed" > "$MARKER"
echo "$VER" > "$VERSION_STATE"

# 4. Start Forkop: it installs its managed /etc/init.d/sing-box and starts sing-box.
/etc/init.d/forkop start
sing_box_healthy || rollback "the lean build did not come up (see: logread -e sing-box)"

rm -rf "$WORK"
say "done: $("$TARGET" version | head -1)"
say "after:"
free -m | sed -n 1,2p
df -h /overlay | tail -1
PID=$(pidof sing-box | awk '{print $1}')
grep -E "VmRSS|RssAnon|RssFile" "/proc/$PID/status"
