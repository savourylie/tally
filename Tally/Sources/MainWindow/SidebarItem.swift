import SwiftUI

struct SidebarItem: View {
    let selection: SidebarSelection
    let isSelected: Bool
    let onSelect: (SidebarSelection) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect(selection)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selection.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 16, height: 16)
                    .foregroundStyle(isSelected ? Color.tally.accent : Color.tally.fg2)

                Text(selection.title)
                    .font(.tally.body)
                    .tracking(Font.tallyTracking.body)
                    .foregroundStyle(isSelected ? Color.tally.fg1 : Color.tally.fg2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s4)
            .padding(.vertical, Spacing.s3)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: Radius.r6))
        }
        .buttonStyle(.plain)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
        .onHover { hovering in
            withAnimation(Motion.hover) {
                isHovered = hovering
            }
        }
        .accessibilityLabel(selection.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.tally.bgSelected
        }

        if isHovered {
            return Color.tally.bgHover
        }

        return Color.clear
    }
}

#Preview {
    VStack(spacing: 2) {
        SidebarItem(selection: .overview, isSelected: true, onSelect: { _ in })
        SidebarItem(selection: .settings, isSelected: false, onSelect: { _ in })
    }
    .padding()
    .frame(width: 200)
    .background(Color.tally.bgSidebar)
}
