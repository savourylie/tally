import AppKit
import SwiftUI

struct MainWindowContent: View {
    @Environment(AppState.self) private var appState

    // TICKET-008 debug — remove when TICKET-015 lands.
    @State private var debugMeta: AppMetadata?
    @State private var debugLabel: String = "AppMetadata debug — tap a button"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("AppState id: \(String(describing: ObjectIdentifier(appState)))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // TICKET-008 debug — remove when TICKET-015 lands.
            metadataDebugBar
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            Divider()
            ScrollView {
                TokensPreviewGrid()
            }
        }
        .frame(width: 1120, height: 800)
    }

    // TICKET-008 debug — remove when TICKET-015 lands.
    private var metadataDebugBar: some View {
        HStack(spacing: 12) {
            Button("Safari") { lookup(bundleID: "com.apple.Safari", label: "Safari") }
            Button("Chrome") { lookup(bundleID: "com.google.Chrome", label: "Chrome") }
            Button("iCloud") { lookup(category: "iCloud", label: "iCloud") }
            Button("Unknown") { lookup(bundleID: "com.fake.notinstalled", label: "Unknown") }
            Button("Perf 1000") { runPerf() }

            Spacer()

            HStack(spacing: 6) {
                if let icon = debugMeta?.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                Text(debugLabel)
                    .font(.caption.monospaced())
                    .foregroundStyle(debugMeta == nil ? .tertiary : .primary)
            }
        }
    }

    // TICKET-008 debug — remove when TICKET-015 lands.
    private func lookup(bundleID: String, label: String) {
        let service = appState.appMetadata
        Task { @MainActor in
            let meta = await service.metadata(forBundleID: bundleID)
            debugMeta = meta
            debugLabel = "\(label) → \(meta.displayName)"
        }
    }

    // TICKET-008 debug — remove when TICKET-015 lands.
    private func lookup(category: String, label: String) {
        let service = appState.appMetadata
        Task { @MainActor in
            let meta = await service.metadata(forCategory: category)
            debugMeta = meta
            debugLabel = "\(label) → \(meta.displayName)"
        }
    }

    // TICKET-008 debug — remove when TICKET-015 lands.
    private func runPerf() {
        let service = appState.appMetadata
        Task { @MainActor in
            _ = await service.metadata(forBundleID: "com.apple.Safari")
            let start = Date()
            for _ in 0..<1000 {
                _ = await service.metadata(forBundleID: "com.apple.Safari")
            }
            let elapsedMs = Date().timeIntervalSince(start) * 1000
            Log.meta.info("[meta] perf 1000 cached lookups elapsed_ms=\(elapsedMs, privacy: .public)")
            debugMeta = nil
            debugLabel = String(format: "Perf 1000 in %.2fms", elapsedMs)
        }
    }
}

#Preview {
    MainWindowContent()
        .environment(AppState())
}
