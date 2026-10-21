# dist

Mirror of the latest lean release binary (gzip) for routers that cannot reach GitHub
release downloads. install-lean.sh fetches it from raw.githubusercontent.com first and from
https://cdn.jsdelivr.net/gh/Hxrmfull/sing-box-extended@dist/ as a last resort.

`sing-box-lean-linux-arm64.sha256` is the checksum of the uncompressed binary.
This branch is rewritten by the "Lean release" workflow on every release; sources are in
branch `lean` and in each release's `-lean-src.tar.gz`.
