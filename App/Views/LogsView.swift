import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LogsView: View {
    @State private var text: String = ""
    @State private var copied: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var refreshTask: Task<Void, Never>? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(text.isEmpty ? "Логи пусты." : text)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
                    .id("logs-end")
            }
            .onAppear {
                reload()
                proxy.scrollTo("logs-end", anchor: .bottom)
            }
            .onDisappear {
                refreshTask?.cancel()
                refreshTask = nil
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Логи")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        copyAll()
                    } label: {
                        Label(copied ? "Скопировано" : "Копировать всё",
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    Button {
                        showShareSheet = true
                    } label: {
                        Label("Поделиться", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        reload()
                    } label: {
                        Label("Обновить", systemImage: "arrow.clockwise")
                    }
                    Divider()
                    Button(role: .destructive) {
                        LogStore.shared.clear()
                        LogStore.shared.info("Logs cleared by user", tag: "UI")
                        reload()
                    } label: {
                        Label("Очистить", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [text])
        }
        #endif
    }

    private func reload() {
        text = LogStore.shared.read()
    }

    private func copyAll() {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
        LogStore.shared.info("Logs copied to clipboard (\(text.count) chars)", tag: "UI")
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { copied = false }
        }
    }
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#endif
