import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Внешний вид") {
                    Picker("Тема", selection: $appViewModel.settings.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.localizedTitle).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Виброотклик", isOn: $appViewModel.settings.hapticsEnabled)
                }

                Section {
                    Picker("Протокол пинга", selection: $appViewModel.settings.pingProtocol) {
                        ForEach(PingProtocol.allCases) { p in
                            Text(p.localizedTitle).tag(p)
                        }
                    }
                    if let subtitle = pingSubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Пинг")
                } footer: {
                    Text("Пинг тестируется до \(PingResult.probeURL.absoluteString)")
                        .font(.caption2)
                }

                Section("Подключение") {
                    Toggle("Автоматическое переподключение", isOn: $appViewModel.settings.autoReconnect)
                    Toggle("Kill Switch", isOn: $appViewModel.settings.killSwitch)
                        .disabled(true)
                }

                Section("Диагностика") {
                    NavigationLink {
                        LogsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Логи")
                                Text("Просмотр и копирование")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "doc.text")
                        }
                    }
                }

                Section {
                    Link(destination: URL(string: "https://t.me/MaksimXyila")!) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("@MaksimXyila")
                                Text("Telegram автора")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            TelegramGlyph().frame(width: 24, height: 24)
                        }
                    }
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text(Bundle.main.shortVersionString + " (" + Bundle.main.buildNumber + ")")
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                } header: {
                    Text("О приложении")
                }
            }
            .navigationTitle("Настройки")
        }
    }

    private var pingSubtitle: String? {
        appViewModel.settings.pingProtocol.subtitle
    }
}

private extension Bundle {
    var shortVersionString: String {
        (object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }
    var buildNumber: String {
        (object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "1"
    }
}
