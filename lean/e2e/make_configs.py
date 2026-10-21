"""Throwaway configs for the lean build's loopback test.

Usage: python3 make_configs.py <gen.txt> <out-dir>

gen.txt holds the output of `sing-box generate reality-keypair`, `generate uuid` and
`generate tls-keypair test.local`. Writes into out-dir:
  server.json  - one inbound per transport the client tests
  client.json  - mixed inbound per outbound (ports 30001..), urltest "auto" on 30000
  forkop.json  - check-only config shaped like Forkop's output (tproxy, fakeip, every
                 outbound type and transport Forkop can generate)
All keys are generated for the test run and are not secrets.
"""
import json
import pathlib
import re
import sys

gen = pathlib.Path(sys.argv[1]).read_text()
out = pathlib.Path(sys.argv[2]).resolve()

priv = re.search(r"PrivateKey: (\S+)", gen).group(1)
pub = re.search(r"PublicKey: (\S+)", gen).group(1)
uuid = re.search(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", gen, re.M).group(0)
pems = re.findall(r"-----BEGIN [A-Z ]+-----.*?-----END [A-Z ]+-----", gen, re.S)
(out / "key.pem").write_text(next(p for p in pems if "PRIVATE" in p) + "\n")
(out / "cert.pem").write_text(next(p for p in pems if "CERTIFICATE" in p) + "\n")

SID = "a1b2c3d4"
SNI = "test.local"
users = [{"uuid": uuid}]
tls_in = {"enabled": True, "server_name": SNI,
          "certificate_path": str(out / "cert.pem"), "key_path": str(out / "key.pem")}
reality_in = {
    "enabled": True,
    "server_name": SNI,
    "reality": {
        "enabled": True,
        "handshake": {"server": "127.0.0.1", "server_port": 20004},
        "private_key": priv,
        "short_id": [SID],
    },
}
xhttp = {"type": "xhttp", "mode": "auto", "path": "/xh", "x_padding_bytes": "100-1000"}
grpc = {"type": "grpc", "service_name": "gs"}

server = {
    "log": {"level": "warn"},
    "inbounds": [
        {"type": "vless", "tag": "xhttp-reality", "listen": "127.0.0.1", "listen_port": 20001,
         "users": users, "tls": reality_in, "transport": xhttp},
        {"type": "vless", "tag": "xhttp-tls", "listen": "127.0.0.1", "listen_port": 20002,
         "users": users, "tls": {**tls_in, "alpn": ["h2", "http/1.1"]}, "transport": xhttp},
        {"type": "vless", "tag": "grpc-reality", "listen": "127.0.0.1", "listen_port": 20003,
         "users": users, "tls": reality_in, "transport": grpc},
        {"type": "vless", "tag": "tls", "listen": "127.0.0.1", "listen_port": 20004,
         "users": users, "tls": tls_in},
        {"type": "hysteria2", "tag": "hy2", "listen": "127.0.0.1", "listen_port": 20005,
         "users": [{"password": "test-only"}], "tls": {**tls_in, "alpn": ["h3"]}},
        {"type": "vless", "tag": "reality-vision", "listen": "127.0.0.1", "listen_port": 20006,
         "users": [{"uuid": uuid, "flow": "xtls-rprx-vision"}], "tls": reality_in},
    ],
    "outbounds": [{"type": "direct", "tag": "direct"}],
}

tls_out = {"enabled": True, "server_name": SNI, "insecure": True,
           "utls": {"enabled": True, "fingerprint": "chrome"}}
reality_out = {"enabled": True, "server_name": SNI,
               "utls": {"enabled": True, "fingerprint": "chrome"},
               "reality": {"enabled": True, "public_key": pub, "short_id": SID}}
xhttp_out = {**xhttp, "host": SNI, "sc_max_each_post_bytes": 1000000, "sc_min_posts_interval_ms": 30}

outs = [
    {"type": "vless", "tag": "xhttp-reality", "server": "127.0.0.1", "server_port": 20001,
     "uuid": uuid, "tls": reality_out, "transport": xhttp_out},
    {"type": "vless", "tag": "xhttp-tls", "server": "127.0.0.1", "server_port": 20002,
     "uuid": uuid, "tls": {**tls_out, "alpn": ["h2", "http/1.1"]}, "transport": xhttp_out},
    {"type": "vless", "tag": "grpc-reality", "server": "127.0.0.1", "server_port": 20003,
     "uuid": uuid, "tls": reality_out, "transport": grpc},
    {"type": "vless", "tag": "tls", "server": "127.0.0.1", "server_port": 20004,
     "uuid": uuid, "tls": tls_out},
    {"type": "hysteria2", "tag": "hy2", "server": "127.0.0.1", "server_port": 20005,
     "password": "test-only", "tls": {"enabled": True, "server_name": SNI, "insecure": True, "alpn": ["h3"]}},
    {"type": "vless", "tag": "reality-vision", "server": "127.0.0.1", "server_port": 20006,
     "uuid": uuid, "flow": "xtls-rprx-vision", "tls": reality_out},
]
names = [o["tag"] for o in outs]

client = {
    "log": {"level": "warn"},
    "dns": {"servers": [{"type": "local", "tag": "local"}], "final": "local"},
    "inbounds": [
        {"type": "mixed", "tag": f"in-{n}", "listen": "127.0.0.1", "listen_port": 30001 + i}
        for i, n in enumerate(names)
    ] + [{"type": "mixed", "tag": "in-auto", "listen": "127.0.0.1", "listen_port": 30000}],
    "outbounds": [
        {"type": "direct", "tag": "direct"},
        {"type": "urltest", "tag": "auto", "outbounds": names,
         "url": "http://127.0.0.1:8080/small", "interval": "1m"},
        *outs,
    ],
    "route": {
        "rules": [{"inbound": [f"in-{n}"], "outbound": n} for n in names]
        + [{"inbound": ["in-auto"], "outbound": "auto"}],
        "final": "direct",
        "default_domain_resolver": "local",
    },
    "experimental": {"clash_api": {"external_controller": "127.0.0.1:9090"}},
}

remote = {"server": "127.0.0.1", "server_port": 443}
forkop_outs = [
    {"type": "vless", "tag": "vless-ws", **remote, "uuid": uuid, "tls": tls_out,
     "transport": {"type": "ws", "path": "/ws", "headers": {"Host": SNI}}},
    {"type": "vless", "tag": "vless-httpupgrade", **remote, "uuid": uuid, "tls": tls_out,
     "transport": {"type": "httpupgrade", "path": "/up", "host": SNI}},
    {"type": "vless", "tag": "vless-http", **remote, "uuid": uuid, "tls": tls_out,
     "transport": {"type": "http", "path": "/h2"}},
    {"type": "vmess", "tag": "vmess-ws", **remote, "uuid": uuid, "security": "auto",
     "transport": {"type": "ws", "path": "/vm"}},
    {"type": "trojan", "tag": "trojan", **remote, "password": "test-only", "tls": tls_out},
    {"type": "shadowsocks", "tag": "ss", **remote, "method": "2022-blake3-aes-128-gcm",
     "password": "AAAAAAAAAAAAAAAAAAAAAA=="},
    {"type": "socks", "tag": "socks", **remote, "version": "5"},
    {"type": "http", "tag": "http-proxy", **remote},
    *outs,
]
forkop = {
    "log": {"level": "warn"},
    "dns": {
        "servers": [
            {"type": "udp", "tag": "dns-server", "server": "77.88.8.8"},
            {"type": "fakeip", "tag": "fakeip-server", "inet4_range": "198.18.0.0/15"},
        ],
        "rules": [
            {"action": "reject", "query_type": "HTTPS"},
            {"action": "route", "server": "fakeip-server", "domain_suffix": ["example.com"]},
        ],
        "final": "dns-server",
        "strategy": "prefer_ipv4",
    },
    "inbounds": [
        {"type": "tproxy", "tag": "tproxy-in", "listen": "127.0.0.1", "listen_port": 1602,
         "tcp_fast_open": True, "udp_fragment": True},
        {"type": "direct", "tag": "dns-in", "listen": "127.0.0.42", "listen_port": 53},
        {"type": "mixed", "tag": "service-mixed-in", "listen": "127.0.0.1", "listen_port": 4534},
    ],
    "outbounds": [
        {"type": "direct", "tag": "direct-out"},
        {"type": "urltest", "tag": "main-auto", "outbounds": [o["tag"] for o in forkop_outs]},
        {"type": "selector", "tag": "main-out", "outbounds": ["main-auto"]},
        *forkop_outs,
    ],
    "route": {
        "rules": [
            {"action": "sniff"},
            {"protocol": "dns", "action": "hijack-dns"},
            {"inbound": ["tproxy-in"], "domain_suffix": ["example.com"], "outbound": "main-out"},
        ],
        "final": "direct-out",
        "auto_detect_interface": True,
        "default_domain_resolver": "dns-server",
    },
    "experimental": {
        "cache_file": {"enabled": True, "path": str(out / "cache.db"), "store_fakeip": True},
        "clash_api": {"external_controller": "127.0.0.1:9090"},
    },
}

for name, cfg in (("server", server), ("client", client), ("forkop", forkop)):
    (out / f"{name}.json").write_text(json.dumps(cfg, indent=2))
print("configs:", ", ".join(names))
