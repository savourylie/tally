import SwiftUI

struct Sidebar: View {
    let selection: SidebarSelection
    let onSelect: (SidebarSelection) -> Void

    var body: some View {
        ZStack {
            Color.tally.bgSidebar

            VisualEffectBackground(
                material: .sidebar,
                blendingMode: .withinWindow,
                state: .active
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("TALLY")
                    .font(.tally.micro)
                    .tracking(Font.tallyTracking.caps)
                    .foregroundStyle(Color.tally.fg3)
                    .padding(.horizontal, Spacing.s4)
                    .padding(.top, Spacing.s4)
                    .padding(.bottom, Spacing.s2)

                SidebarItem(
                    selection: .overview,
                    isSelected: selection == .overview,
                    onSelect: onSelect
                )

                SidebarItem(
                    selection: .settings,
                    isSelected: selection == .settings,
                    onSelect: onSelect
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s2)
            .padding(.bottom, Spacing.s3)
        }
        .frame(width: MainWindowLayout.sidebarWidth)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.tally.border)
                .frame(width: 1)
        }
    }
}

#Preview {
    Sidebar(selection: .overview, onSelect: { _ in })
        .frame(height: 640)
}
