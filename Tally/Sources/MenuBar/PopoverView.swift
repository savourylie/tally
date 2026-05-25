import SwiftUI

struct PopoverView: View {
    @Environment(AppState.self) private var appState
    @Environment(Preferences.self) private var preferences
    @Environment(\.openWindow) private var openWindow
    
    @State private var isVisible = false
    
    // Injectable mock properties for Xcode Preview rendering
    var mockStoreState: UsageStore.State? = nil
    var mockBytes: UsageStore.BytePair? = nil
    var mockTopEntries: [AppUsageEntry]? = nil
    var mockCapBytes: Int64? = nil
    var mockNetworkName: String? = nil
    var mockLastSampleTimestamp: Int64? = nil
    var mockDailyTrend: [DailyUsage]? = nil
    
    var body: some View {
        let store = appState.usageStore
        let state = mockStoreState ?? store.state
        let bytes = mockBytes ?? store.monthToDateBytes
        let topEntries = mockTopEntries ?? store.topApps(limit: 5)
        let capBytes = mockCapBytes ?? store.monthlyCapBytes
        let networkConnection = mockNetworkName.map(NetworkConnection.wifi(name:)) ?? store.currentNetwork
        let lastSampleTimestamp = mockLastSampleTimestamp ?? store.lastSampleTimestamp
        let dailyTrend = mockDailyTrend ?? store.dailyTrend
        
        let totalBytes = bytes.bytesIn + bytes.bytesOut
        
        VStack(spacing: 0) {
            if !preferences.onboardingComplete {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.tally.accent)
                        .padding(.top, 10)
                    
                    Text("請先完成設定")
                        .font(.tally.title2)
                        .tracking(Font.tallyTracking.title2)
                        .foregroundStyle(Color.tally.fg1)
                    
                    Text("請打開 Tally 主視窗完成首次安裝與流量設定。")
                        .font(.tally.callout)
                        .tracking(Font.tallyTracking.callout)
                        .foregroundStyle(Color.tally.fg3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    
                    Button(action: {
                        openWindow(id: "main")
                    }) {
                        Text("開始設定")
                            .font(.tally.bodyEm)
                            .tracking(Font.tallyTracking.body)
                            .foregroundStyle(Color.tally.accentOn)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.tally.accent)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                }
            } else if state == .collecting {
                CollectingPlaceholder()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero number MTD + cap remaining info
                    HeroNumber(
                        monthToDateBytes: totalBytes,
                        monthlyCapBytes: capBytes
                    )
                    .padding(.bottom, capBytes != nil ? 10 : 8)
                    
                    // Progress Bar
                    ProgressBar(
                        monthToDateBytes: totalBytes,
                        monthlyCapBytes: capBytes
                    )
                    .padding(.bottom, 8)
                    
                    // Network connection line + freshness ("● 即時 / 更新於 X 前")
                    VStack(alignment: .leading, spacing: 3) {
                        NetworkLine(connection: networkConnection)
                        FreshnessLabel(lastSampleTimestamp: lastSampleTimestamp)
                    }
                    .padding(.bottom, 14)
                    
                    // Recent-usage sparkline — quiet glanceable trend (ready state only)
                    if !dailyTrend.isEmpty {
                        Sparkline(trend: dailyTrend)
                            .padding(.bottom, 10)
                    }

                    // Top 5 apps list header
                    Text("這個月用最多的")
                        .font(.tally.micro)
                        .tracking(Font.tallyTracking.caps)
                        .foregroundStyle(Color.tally.fg3)
                        .padding(.bottom, 6)
                    
                    // Apps rows
                    VStack(spacing: 2) {
                        ForEach(topEntries) { entry in
                            TopAppRow(entry: entry)
                                .background(HoverBackground())
                                .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
                        }
                    }
                }
            }
            
            // Divider
            Divider()
                .background(Color.tally.divider)
                .padding(.horizontal, -14)
                .padding(.top, 10)
                .padding(.bottom, 8)
            
            // Footer
            HStack(spacing: 6) {
                Button(action: {
                    openWindow(id: "main")
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .semibold))
                        Text("打開完整畫面")
                            .font(.tally.bodyEm)
                            .tracking(Font.tallyTracking.body)
                    }
                    .foregroundStyle(Color.tally.fg1)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .background(HoverBackground())
                .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
                
                Spacer()
                
                Button(action: {
                    appState.mainWindow.selection = .settings
                    openWindow(id: "main")
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.tally.fg2)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .background(HoverBackground())
                .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(VisualEffectBackground(material: .popover))
        .clipShape(RoundedRectangle(cornerRadius: Radius.r10))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.r10)
                .stroke(Color.tally.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 2)
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 12)
        .scaleEffect(isVisible ? 1.0 : 0.96)
        .opacity(isVisible ? 1.0 : 0)
        .onAppear {
            withAnimation(Motion.popover) {
                isVisible = true
            }
        }
    }
}

// MARK: - Hover Helper

struct HoverBackground: View {
    @State private var isHovered = false
    var hoverColor: Color = Color.tally.bgHover
    
    var body: some View {
        Color.clear
            .background(isHovered ? hoverColor : Color.clear)
            .onHover { hovering in
                withAnimation(Motion.hover) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Previews

private func popoverMockTrend() -> [DailyUsage] {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    return (0..<14).map { offset in
        let date = cal.date(byAdding: .day, value: -(13 - offset), to: today) ?? today
        return DailyUsage(
            date: date,
            bytesIn: Int64(300_000_000 + (offset % 7) * 180_000_000),
            bytesOut: Int64(40_000_000 + (offset % 5) * 30_000_000)
        )
    }
}

#Preview("Ready State (5 Apps)") {
    let mockApps = [
        AppUsageEntry(
            kind: .app(bundleID: "com.google.Chrome"),
            bytesIn: 4_200_000_000,
            bytesOut: 800_000_000,
            metadata: AppMetadata(displayName: "Chrome", icon: NSWorkspace.shared.icon(for: .application))
        ),
        AppUsageEntry(
            kind: .app(bundleID: "com.apple.dt.Xcode"),
            bytesIn: 2_100_000_000,
            bytesOut: 400_000_000,
            metadata: AppMetadata(displayName: "Xcode", icon: NSWorkspace.shared.icon(for: .application))
        ),
        AppUsageEntry(
            kind: .app(bundleID: "com.tinyspeck.slackmacgap"),
            bytesIn: 1_200_000_000,
            bytesOut: 300_000_000,
            metadata: AppMetadata(displayName: "Slack", icon: NSWorkspace.shared.icon(for: .application))
        ),
        AppUsageEntry(
            kind: .app(bundleID: "com.apple.Safari"),
            bytesIn: 800_000_000,
            bytesOut: 200_000_000,
            metadata: AppMetadata(displayName: "Safari", icon: NSWorkspace.shared.icon(for: .application))
        ),
        AppUsageEntry(
            kind: .category(name: "iCloud"),
            bytesIn: 400_000_000,
            bytesOut: 100_000_000,
            metadata: AppMetadata(displayName: "iCloud 雲端服務", icon: NSImage(systemSymbolName: "icloud.fill", accessibilityDescription: nil) ?? NSImage())
        )
    ]
    
    PopoverView(
        mockStoreState: .ready,
        mockBytes: UsageStore.BytePair(bytesIn: 8_700_000_000, bytesOut: 1_800_000_000),
        mockTopEntries: mockApps,
        mockCapBytes: 20 * 1024 * 1024 * 1024,
        mockNetworkName: "家裡的 Wi-Fi",
        mockLastSampleTimestamp: Int64(Date.now.timeIntervalSince1970) - 60,
        mockDailyTrend: popoverMockTrend()
    )
    .padding()
    .environment(AppState())
}

#Preview("Ready State (No Cap)") {
    let mockApps = [
        AppUsageEntry(
            kind: .app(bundleID: "com.google.Chrome"),
            bytesIn: 4_200_000_000,
            bytesOut: 800_000_000,
            metadata: AppMetadata(displayName: "Chrome", icon: NSWorkspace.shared.icon(for: .application))
        )
    ]
    
    PopoverView(
        mockStoreState: .ready,
        mockBytes: UsageStore.BytePair(bytesIn: 4_200_000_000, bytesOut: 800_000_000),
        mockTopEntries: mockApps,
        mockCapBytes: nil,
        mockNetworkName: "家裡的 Wi-Fi",
        mockLastSampleTimestamp: Int64(Date.now.timeIntervalSince1970) - 60,
        mockDailyTrend: popoverMockTrend()
    )
    .padding()
    .environment(AppState())
}

#Preview("Collecting State") {
    PopoverView(
        mockStoreState: .collecting
    )
    .padding()
    .environment(AppState())
}
