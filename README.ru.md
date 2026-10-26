# sing-box-extended lean

Облегчённая сборка [sing-box-extended](https://github.com/shtorm-7/sing-box-extended) с XHTTP
для [Forkop](https://github.com/ushan0v/forkop) на роутерах OpenWrt.

[English](README.md)

![Forkop с установленной лёгкой сборкой](docs/forkop-components.png)

## Возможности

- Протоколы: VLESS, VMess, Trojan, Shadowsocks, SOCKS, HTTP и Hysteria2.
- Транспорты: XHTTP, WebSocket, gRPC, HTTPUpgrade и HTTP, с TLS, Reality и uTLS.
- Бинарник весит около 26 МБ вместо 93. Он не сжат UPX, поэтому читается с флеша,
  а не распаковывается в оперативку.
- На роутере с 256 МБ оперативки остаётся свободно около 103 МБ (с Extended compressed — около 12 МБ).
- Мягкий лимит памяти Go — 64 МБ.
- Установщик сначала проверяет ваш конфиг Forkop. Если новая сборка не запустилась,
  он сам возвращает прежнюю.
- Новые версии автора пересобираются и тестируются автоматически.

## Установка

Нужен роутер на OpenWrt с процессором aarch64 (например, MT7981) и установленным Forkop.
Выполните на роутере:

```sh
sh <(wget -O - https://raw.githubusercontent.com/Hxrmfull/sing-box-extended/lean/install-lean.sh)
```

Бинарники лежат и на странице [Releases](https://github.com/Hxrmfull/sing-box-extended/releases).
Для роутера нужен `sing-box-lean-linux-arm64`.

## Использование

После установки Forkop работает со сборкой как обычно. На вкладке «Компоненты» она видна как
`…+lean (compressed)`.

| Действие | Как |
|---|---|
| Обновить | Снова выполнить команду установки |
| Откатиться | Forkop → Компоненты → Stable |
| Узнать версию | `sing-box version` |

Не обновляйте sing-box из Forkop и не нажимайте там Extended: так поставится тяжёлая сжатая сборка.

## Сборка

```sh
git clone --depth 1 --branch v1.14.3-extended-2.7.3 https://github.com/shtorm-7/sing-box-extended upstream
sh lean/apply.sh upstream
cd upstream && LEAN_BASE_VERSION=1.14.3-extended-2.7.3 sh build-lean.sh arm64
```

Нужен Go той версии, что указана в `go.mod` автора. Бинарник появится в `upstream/dist/`.

## Лицензия

GPL-3.0, как у sing-box-extended.
