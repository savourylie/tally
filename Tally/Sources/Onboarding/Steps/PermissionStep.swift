import SwiftUI

struct PermissionStep: View {
    let activator: SystemExtensionActivator
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Banner Art
            ZStack {
                Color.tally.brand50
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.tally.accent)
            }
            .frame(height: 168)
            .overlay(
                Rectangle()
                    .fill(Color.tally.border)
                    .frame(height: 1),
                alignment: .bottom
            )
            
            // Content
            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text("第 2 步 / 共 3 步")
                    .font(.tally.micro)
                    .tracking(Font.tallyTracking.caps)
                    .foregroundStyle(Color.tally.fg3)
                
                Text("幫我看見網路")
                    .font(.tally.title1)
                    .tracking(Font.tallyTracking.title1)
                    .foregroundStyle(Color.tally.fg1)
                
                VStack(alignment: .leading, spacing: Spacing.s3) {
                    Text("Tally 需要『看見』你的網路使用情況，才能告訴你每個 app 用了多少。")
                        .font(.tally.body)
                        .tracking(Font.tallyTracking.body)
                        .foregroundStyle(Color.tally.fg2)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Disclosure Group
                    DisclosureGroup(
                        isExpanded: $isExpanded,
                        content: {
                            Text("Tally 需要安裝一個系統小工具（Network Extension）來取得各個應用程式的網路流量統計。這個工具完全在你的 Mac 上本機運作，不會攔截、阻止任何連線，也絕對不會把資料傳送給任何人。")
                                .font(.tally.callout)
                                .tracking(Font.tallyTracking.callout)
                                .foregroundStyle(Color.tally.fg3)
                                .lineSpacing(3)
                                .padding(.top, Spacing.s2)
                                .fixedSize(horizontal: false, vertical: true)
                        },
                        label: {
                            HStack(spacing: Spacing.s1) {
                                Text("為什麼需要這個權限？")
                                    .font(.tally.bodyEm)
                                    .tracking(Font.tallyTracking.body)
                                    .foregroundStyle(Color.tally.accent)
                            }
                        }
                    )
                    .disclosureGroupStyle(SimpleDisclosureGroupStyle())
                    
                    HStack(alignment: .top, spacing: Spacing.s3) {
                        Image(systemName: statusIconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(statusColor)
                            .frame(width: 18, height: 18)
                            .padding(.top, 1)
                        Text(activator.state.userMessage)
                            .font(.tally.callout)
                            .tracking(Font.tallyTracking.callout)
                            .foregroundStyle(Color.tally.fg2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Spacing.s3)
                    .background(Color.tally.bgCardAlt)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.r8))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.r8)
                            .stroke(Color.tally.border, lineWidth: 1)
                    )
                    .padding(.top, Spacing.s1)

                    HStack(spacing: Spacing.s2) {
                        Button(action: {
                            activator.openSecuritySettings()
                        }) {
                            HStack(spacing: Spacing.s2) {
                                Image(systemName: "gearshape.2")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("去設定")
                                    .font(.tally.bodyEm)
                                    .tracking(Font.tallyTracking.body)
                            }
                            .foregroundStyle(Color.tally.accent)
                            .padding(.horizontal, Spacing.s4)
                            .padding(.vertical, Spacing.s2)
                            .background(Color.tally.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
                        }
                        .buttonStyle(.plain)

                        if activator.state.canRetry {
                            Button(action: {
                                activator.requestActivation()
                            }) {
                                HStack(spacing: Spacing.s2) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("再試一次")
                                        .font(.tally.bodyEm)
                                        .tracking(Font.tallyTracking.body)
                                }
                                .foregroundStyle(Color.tally.fg2)
                                .padding(.horizontal, Spacing.s4)
                                .padding(.vertical, Spacing.s2)
                                .background(Color.tally.bgHover)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Spacer(minLength: 8)
                    
                    // VPN note
                    HStack(spacing: Spacing.s2) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.tally.fg3)
                        Text("如果你常開 VPN，Tally 可能看不到每個 app 的細節")
                            .font(.tally.caption)
                            .tracking(Font.tallyTracking.caption)
                            .foregroundStyle(Color.tally.fg3)
                    }
                    .padding(.top, Spacing.s2)
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 26)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
        }
        .onAppear {
            activator.requestActivationIfNeeded()
        }
    }

    private var statusIconName: String {
        switch activator.state {
        case .idle, .activating:
            return "arrow.triangle.2.circlepath"
        case .waitingForApproval:
            return "exclamationmark.triangle.fill"
        case .enabled:
            return "checkmark.circle.fill"
        case .denied, .failed:
            return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch activator.state {
        case .enabled:
            return Color.tally.success
        case .waitingForApproval:
            return Color.tally.warning
        case .denied, .failed:
            return Color.tally.danger
        case .idle, .activating:
            return Color.tally.accent
        }
    }
}

// Custom Disclosure Group Style to remove the default background/indentation styling of macOS DisclosureGroup
struct SimpleDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    configuration.isExpanded.toggle()
                }
            }) {
                HStack(spacing: Spacing.s1) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.tally.accent)
                        .frame(width: 12, height: 12)
                    configuration.label
                }
            }
            .buttonStyle(.plain)
            
            if configuration.isExpanded {
                configuration.content
                    .padding(.leading, 16)
            }
        }
    }
}

#Preview {
    PermissionStep(activator: SystemExtensionActivator())
        .frame(width: 540, height: 460)
        .background(Color.tally.bgCard)
}
