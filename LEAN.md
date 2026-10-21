# sing-box-extended lean — для Forkop на роутерах

Облегчённая сборка [sing-box-extended](https://github.com/shtorm-7/sing-box-extended) с XHTTP
для [Forkop](https://github.com/ushan0v/forkop) на OpenWrt (aarch64, например MT7981 / Cudy WR3000S).
Изменения лежат в ветке `lean`.

## Зачем

Полная extended-сборка под arm64 весит около 93 МБ. Вариант «Extended compressed» в Forkop сжат UPX
и при запуске целиком распаковывается в оперативку. На роутере с 256 МБ после этого почти ничего
не остаётся. Лёгкая сборка весит около 26 МБ и не сжата: ядро читает её с флеша по мере надобности.

Замер на тестовом конфиге, x86, после 300 МБ трафика:

| Сборка | Память процесса | Из неё нельзя освободить |
|---|---|---|
| полная + UPX | 101 МБ | ~100 МБ |
| полная | 67 МБ | 18 МБ |
| **lean** | **32 МБ** | **10 МБ** |

## Что внутри

- Протоколы, которые генерирует Forkop: VLESS, VMess, Trojan, Shadowsocks, SOCKS, HTTP, Hysteria2.
- Транспорты: XHTTP, WebSocket, gRPC, HTTPUpgrade, HTTP. Защита: TLS, Reality, uTLS.
- Входящие tproxy, redirect, tun, direct, mixed; DNS (udp/tcp/tls/https/quic/local/fakeip);
  группы urltest и selector; clash API.
- Мягкий лимит памяти Go 64 МБ и `GOGC=50`. Переменные окружения `GOMEMLIMIT` и `GOGC` его перекрывают.

Убраны WARP/MASQUE, MTProxy, Tailscale, WireGuard, OpenVPN/OpenConnect, Snell, Mieru, Tor, SSH,
AnyTLS, ShadowTLS, NaïveProxy, менеджер-API и команда `sing-box api`.

Все изменения включаются только тегом сборки `lean`. Без него код собирается как оригинал:
- `include/registry_lean.go` — урезанный список протоколов;
- `cmd/sing-box/lean_memlimit.go` — лимит памяти;
- `cmd/sing-box/cmd_api*.go` — исключены в сборке `lean`.

## Установка на роутер с Forkop

```sh
sh <(wget -O - https://raw.githubusercontent.com/Hxrmfull/sing-box-extended/lean/install-lean.sh)
```

Как работает скрипт:
1. Скачивает бинарник в gzip (около 10 МБ) и сверяет SHA-256. Источники перебираются по порядку,
   пока один не сработает: ветка `dist` через raw.githubusercontent.com, релизы GitHub,
   релизы через прокси Forkop (если в Forkop включена загрузка через прокси), jsDelivr.
2. Проверяет текущий конфиг Forkop командой `sing-box check`. Если что-то не так,
   останавливается и ничего не меняет.
3. Сохраняет копию текущего sing-box в `/tmp`, чтобы откат работал без интернета.
4. Ставит сборку как вариант Forkop `extended-compressed`: init-скрипт ведёт сам Forkop,
   а настройки Forkop не меняются.
5. Проверяет, что sing-box запустился и отвечает на DNS. Если нет, сам возвращает прежнюю версию.

**Не обновляйте sing-box кнопкой в Forkop**: так поставится тяжёлая сжатая сборка.
Чтобы обновить lean-сборку, запустите ту же команду установки ещё раз.
Откат: Forkop → Компоненты → Stable.

## Сборка

```sh
sh build-lean.sh arm64
```

Нужен Go версии из `go.mod`. Результат появится в `dist/`.
