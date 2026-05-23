import SwiftUI

struct AppRow: View {
    let entry: AppUsageEntry
    let totalCycleBytes: Int64

    @State private var isHovered = false
    @State private var isPressed = false

    init(entry: AppUsageEntry, totalCycleBytes: Int64) {
        self.entry = entry
        self.totalCycleBytes = totalCycleBytes
        
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

    private var percentageString: String {
        guard totalCycleBytes > 0 else { return "(0%)" }
        let pct = Double(entry.totalBytes) / Double(totalCycleBytes) * 100
        return String(format: "(%.0f%%)", pct)
    }

    var body: some View {
        HStack(spacing: Spacing.s3) {
            // App Icon
            Image(nsImage: entry.metadata.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: Radius.r8))
                .padding(.leading, Spacing.s4)

            // App/Category Name
            Text(entry.metadata.displayName)
                .font(.tally.body)
                .tracking(Font.tallyTracking.body)
                .foregroundStyle(Color.tally.fg1)
                .lineLimit(1)

            Spacer()

            // Data Usage value
            Text(formattedBytes)
                .font(.tally.callout)
                .monospacedDigit()
                .foregroundStyle(Color.tally.fg1)

            // Percentage
            Text(percentageString)
                .font(.tally.callout)
                .foregroundStyle(Color.tally.fg3)
                .padding(.trailing, Spacing.s4)
        }
        .frame(height: 56)
        .background(
            RoundedRectangle(cornerRadius: Radius.r8)
                .fill(Color.tally.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.r8)
                .stroke(Color.tally.border, lineWidth: 1)
        )
        .overlay(
            // Hover overlay: 5% background darken using transparent black
            // Press overlay: 4% darker than hover (9% total darken)
            RoundedRectangle(cornerRadius: Radius.r8)
                .fill(
                    isPressed ? Color.black.opacity(0.09) :
                    (isHovered ? Color.black.opacity(0.05) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(Motion.hover) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}
