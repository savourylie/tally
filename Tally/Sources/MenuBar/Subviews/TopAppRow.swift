import SwiftUI

struct TopAppRow: View {
    let entry: AppUsageEntry

    init(entry: AppUsageEntry) {
        self.entry = entry
        
        #if DEBUG
        let name = entry.metadata.displayName
        if name.contains(".") || name.starts(with: "com/") {
            assertionFailure("Leaking bundle ID in display name: \(name)")
        }
        #endif
    }

    private var formattedBytes: String {
        let bytes = entry.totalBytes
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 0.01 {
            return String(format: "%.2f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.1f MB", mb)
        }
    }

    var body: some View {
        HStack(spacing: Spacing.s2) {
            // App Icon
            Image(nsImage: entry.metadata.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: Radius.r4))
            
            // App / Category Name
            Text(entry.metadata.displayName)
                .font(.tally.body)
                .foregroundStyle(Color.tally.fg1)
                .lineLimit(1)
            
            Spacer()
            
            // Data Usage
            Text(formattedBytes)
                .font(.tally.mono)
                .tracking(Font.tallyTracking.mono)
                .foregroundStyle(Color.tally.fg2)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    let mockApp = AppUsageEntry(
        kind: .app(bundleID: "com.apple.Safari"),
        bytesIn: 4_200_000_000,
        bytesOut: 800_000_000,
        metadata: AppMetadata(displayName: "Safari", icon: NSWorkspace.shared.icon(for: .application))
    )
    TopAppRow(entry: mockApp)
        .padding()
        .frame(width: 320)
}
