# VPN Client (iOS)

Минималистичный iOS VPN-клиент на VLESS+Reality (Xray-core) с виджетами,
вибрацией, splash-экраном и брендированной плашкой во время Reachability.

> Сервер: `2.26.53.100`
> Автор: [@MaksimXyila](https://t.me/MaksimXyila)

## Возможности

- Большая кнопка вкл/выкл VPN с тактильным откликом.
- Таймер активного подключения, статистика трафика (rx/tx) и скорость.
- Список из 3 серверов:
  1. `2.26.53.100:443` — обычный VPN, SNI `www.yandex.ru`.
  2. `2.26.53.100:4443` — обычный VPN, SNI `vk.com`.
  3. `2.26.53.100:2096` — обход белых списков (ТСПУ): RU-домены direct,
     остальное через прокси.
- Кнопка пинга для каждого сервера (TCP / HTTP GET / HEAD / ICMP),
  цель — `https://www.gstatic.com/generate_204`.
- Виджеты Home Screen (small + medium) и Lock Screen (circular / rectangular /
  inline) с быстрым тогглом VPN через `AppIntent`.
- Настройки: тема (системная / светлая / тёмная), протокол пинга, виброотклик.
- Splash-экран с плавным появлением и исчезновением: «VPN CLIENT» + строка
  «@MaksimXyila» с иконкой Telegram.
- Брендированная плашка с «@MaksimXyila» в верхней области, появляющейся при
  активации Reachability (свайп вниз по home indicator).

## Архитектура

```
App/                # SwiftUI приложение (главный таргет)
  Views/            # ConnectionView, ServerListView, SettingsView, SplashView…
  ViewModels/       # AppViewModel — единый источник состояния
  Services/         # VPNManager, PingService, HapticsService, CountryLookupService
  Intents/          # ToggleVPNIntent (для виджетов / Siri / Shortcuts)
PacketTunnel/       # NEPacketTunnelProvider extension
  XrayController.swift   # bridge на libXray через dlsym
Widget/             # WidgetKit extension
Shared/             # Модели и хранилища, общие через App Group
Vendor/             # Сюда положи LibXray.xcframework
.github/workflows/  # GitHub Actions CI (xcodebuild на macos-14)
```

Состояние шарится между app / extension / widget через `App Group`
(`group.com.tt2819ais.vpnclient`) — `UserDefaults(suiteName:)` хранит сериализо-
ванные `Server`, `AppSettings`, `ConnectionInfo`.

## Сборка локально

Требования: macOS 14, Xcode 15.4+.

```sh
brew install xcodegen
xcodegen generate
open VPNClient.xcodeproj
```

Скрипт CI делает то же самое — см. `.github/workflows/ios.yml`.

## Подпись и provisioning

Project использует автоподпись (`CODE_SIGN_STYLE=Automatic`). Перед запуском
на устройстве:

1. В Xcode → выбери таргет `VPNClient` → **Signing & Capabilities** → выбери
   свою команду (`DEVELOPMENT_TEAM`).
2. Аналогично для `PacketTunnel` и `VPNClientWidget`.
3. **Capabilities** для каждого таргета должны включать:
   - `App Groups` → `group.com.tt2819ais.vpnclient` (или поменяй на свой и
     обнови entitlements + `AppGroup.identifier`).
   - Для `VPNClient` и `PacketTunnel` дополнительно: **Network Extensions
     → Packet Tunnel**.

Bundle id'ы по умолчанию (можно поменять в `project.yml`):

| Target            | Bundle ID                           |
|-------------------|-------------------------------------|
| VPNClient         | `com.tt2819ais.vpnclient`           |
| PacketTunnel      | `com.tt2819ais.vpnclient.tunnel`    |
| VPNClientWidget   | `com.tt2819ais.vpnclient.widget`    |
| App Group         | `group.com.tt2819ais.vpnclient`     |

## Vendoring libXray

PacketTunnelProvider вызывает функции `LibXrayRun`, `LibXrayStop`,
`LibXrayQueryStats` через `dlsym`, поэтому проект **компилируется без
бинарника** — функции просто заглушены при отсутствии. Чтобы поднять реальный
туннель, нужен `LibXray.xcframework`:

1. Склонируй [`XTLS/libXray`](https://github.com/XTLS/libXray) и собери для
   Apple-платформ:

   ```sh
   git clone https://github.com/XTLS/libXray
   cd libXray
   ./build/Apple/build.sh    # см. инструкции в репозитории libXray
   ```

   Или скачай свежий `LibXray.xcframework.zip` из релизов проекта.

2. Положи `LibXray.xcframework` в `Vendor/LibXray.xcframework`.

3. Открой `VPNClient.xcodeproj` → таргет `PacketTunnel` →
   **General → Frameworks, Libraries, and Embedded Content → +** →
   **Add Other… → Add Files…** → выбери `Vendor/LibXray.xcframework` →
   **Embed: Embed & Sign**.

4. Та же процедура для `VPNClient` (на случай тестов).

После этого rebuild — туннель полноценно подключается через xray-core.

## Конфиг сервера (already provisioned)

На `2.26.53.100` уже стоит и работает Xray 26.3.27 с тремя VLESS+Reality inbound:

```jsonc
// /usr/local/etc/xray/config.json (фрагмент)
{
  "inbounds": [
    { "tag": "vless-reality-yandex", "port": 443,  "streamSettings": { "realitySettings": { "serverNames": ["www.yandex.ru"] } } },
    { "tag": "vless-reality-vk",     "port": 4443, "streamSettings": { "realitySettings": { "serverNames": ["vk.com"] } } },
    { "tag": "vless-reality-avito",  "port": 2096, "streamSettings": { "realitySettings": { "serverNames": ["www.avito.ru"] } } }
  ]
}
```

Reality-параметры (одни на все три inbound):

```
PrivateKey: wD04z5_HkJONHIhTm9ikv1cYp7PugOr4izSSRu8PMmI
PublicKey:  DOUMGEh9tPjkaVgbq5FuEpbnEzzCnbFTsIJF8nEjVR4
shortId:    6ee75049e018a62a
UUID:       eb208d5a-9438-4400-b000-058288c3b1b1
flow:       xtls-rprx-vision
```

Эти значения захардкожены в `Shared/Models/Server.swift` (`Server.bundled`) —
можно править там либо в Settings → Серверы → Edit.

## CI

GitHub Actions (`.github/workflows/ios.yml`) запускается на каждый push и PR:

1. Устанавливает `xcodegen` через brew.
2. Генерирует `VPNClient.xcodeproj` из `project.yml`.
3. Резолвит SwiftPM-зависимости.
4. Собирает таргет `VPNClient` (без подписи) для iOS Simulator.
5. Прогоняет `VPNClientTests` (smoke-тесты на конфиг и список серверов).

## Reachability-плашка

iOS активирует Reachability, когда пользователь свайпает по home indicator:
содержимое уезжает вниз, в верхней части экрана появляется свободное место.
`ReachabilityBannerHost` отслеживает изменение `safeAreaInsets.top` через
`UIViewController.viewSafeAreaInsetsDidChange`. Когда дельта от baseline
превышает 40 pt — мы рисуем синюю плашку с `@MaksimXyila` и иконкой Telegram
во всю ширину дополнительной зоны.

## Тесты на устройстве

Виджеты и `NEPacketTunnelProvider` **не запускаются на iOS Simulator** — для
конца-в-конец тестирования нужен физический iPhone и Apple Developer
аккаунт.
