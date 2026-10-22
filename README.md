# sing-box-extended lean

Облегчённая сборка [sing-box-extended](https://github.com/shtorm-7/sing-box-extended)
для [Forkop](https://github.com/ushan0v/forkop) на роутерах OpenWrt (aarch64).
XHTTP работает, а памяти сборка занимает примерно как stable.

| | Extended compressed | **lean** |
|---|---|---|
| Бинарник | ~93 МБ, сжат UPX | **~26 МБ, без сжатия** |
| Свободная память на роутере с 256 МБ ОЗУ (Cudy WR3000S) | ~12 МБ | **~103 МБ** |

Сжатая UPX сборка при запуске целиком распаковывается в оперативку. Лёгкая сборка
читается с флеша по мере надобности.

## Установка

На роутере с Forkop:

```sh
sh <(wget -O - https://raw.githubusercontent.com/Hxrmfull/sing-box-extended/lean/install-lean.sh)
```

Как работает скрипт:
- проверяет текущий конфиг Forkop новой сборкой;
- сохраняет копию прежнего sing-box;
- если новая сборка не запустилась, сам откатывается на прежнюю.

Настройки Forkop скрипт не меняет.

- **Обновление:** та же команда.
- **Откат:** Forkop → Компоненты → Stable.
- **Кнопкой в Forkop sing-box не обновляйте:** она поставит обратно тяжёлую сборку.

## Что внутри

Оставлено только то, что генерирует Forkop:
- протоколы: VLESS, VMess, Trojan, Shadowsocks, SOCKS, HTTP, Hysteria2;
- транспорты: XHTTP, WebSocket, gRPC, HTTPUpgrade, HTTP;
- защита: TLS, Reality, uTLS;
- tproxy, DNS с FakeIP, группы urltest и selector, clash API.

Убраны WARP/MASQUE, MTProxy, Tailscale, WireGuard, OpenVPN/OpenConnect, Snell, Mieru, Tor,
SSH, AnyTLS, ShadowTLS, NaïveProxy и менеджер-API. Добавлен мягкий лимит памяти Go 64 МБ.

## Как устроен форк

Исходники автора здесь не хранятся, в ветке лежат только наши изменения:

| Файл | Назначение |
|---|---|
| `include/registry_lean.go` | урезанный список протоколов (тег сборки `lean`) |
| `cmd/sing-box/lean_memlimit.go` | лимит памяти по умолчанию |
| `lean/apply.sh` | накладывает изменения на чистые исходники sing-box-extended |
| `build-lean.sh` | сборка |
| `install-lean.sh` | установщик для роутера |
| `lean/e2e/` | тест: трафик через XHTTP, Reality, gRPC, TLS, Hysteria2, Vision |

Раз в сутки GitHub Actions проверяет новые релизы автора. Если вышла новая версия, workflow:
1. накладывает на неё изменения;
2. собирает версии для arm64 и amd64;
3. прогоняет тест обоих бинарников (arm64 запускается в QEMU);
4. публикует релиз `<версия>-lean`.

Полные исходники каждой сборки лежат в релизе, в архиве `-lean-src.tar.gz`.

Лицензия GPL-3.0, как у оригинала.
