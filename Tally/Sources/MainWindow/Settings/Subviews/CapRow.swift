import SwiftUI

struct CapRow: View {
    @Bindable var preferences: Preferences

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                Text("每月可以用多少")
                    .font(.tally.bodyEm)
                    .tracking(Font.tallyTracking.body)
                    .foregroundStyle(Color.tally.fg1)
                
                Text("若沒有上限，Tally 只追蹤、不警告。")
                    .font(.tally.callout)
                    .tracking(Font.tallyTracking.callout)
                    .foregroundStyle(Color.tally.fg3)
            }
            
            Spacer(minLength: Spacing.s6)
            
            HStack(spacing: Spacing.s3) {
                if let limit = preferences.monthlyLimitGB {
                    Button(action: {
                        withAnimation(Motion.hover) {
                            preferences.monthlyLimitGB = nil
                        }
                    }) {
                        Text("清除上限")
                            .font(.tally.callout)
                            .tracking(Font.tallyTracking.callout)
                            .foregroundStyle(Color.tally.fg3)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 0) {
                        Button(action: {
                            let val = Int(limit)
                            if val > 1 {
                                preferences.monthlyLimitGB = Double(val - 1)
                            }
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Color.tally.bgHover)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Text("\(Int(limit)) GB")
                            .font(.tally.body.bold())
                            .tracking(Font.tallyTracking.body)
                            .foregroundStyle(Color.tally.fg1)
                            .frame(width: 60, alignment: .center)
                        
                        Button(action: {
                            let val = Int(limit)
                            preferences.monthlyLimitGB = Double(val + 1)
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Color.tally.bgHover)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, Spacing.s2)
                    .padding(.vertical, Spacing.s1)
                    .background(Color.tally.bgCardAlt)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.r8))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.r8)
                            .stroke(Color.tally.border, lineWidth: 1)
                    )
                } else {
                    Text("沒有上限")
                        .font(.tally.callout)
                        .tracking(Font.tallyTracking.callout)
                        .foregroundStyle(Color.tally.fg3)
                        .padding(.horizontal, Spacing.s3)
                        .padding(.vertical, Spacing.s1)
                        .background(Color.tally.bgHover)
                        .clipShape(Capsule())
                    
                    Button(action: {
                        withAnimation(Motion.hover) {
                            preferences.monthlyLimitGB = 20
                        }
                    }) {
                        Text("設定上限")
                            .font(.tally.bodyEm)
                            .tracking(Font.tallyTracking.body)
                            .foregroundStyle(Color.tally.accent)
                            .padding(.horizontal, Spacing.s3)
                            .padding(.vertical, Spacing.s1)
                            .background(Color.tally.accentSoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, Spacing.s2)
    }
}

#Preview("No Cap") {
    CapRow(preferences: Preferences())
        .padding()
        .background(Color.tally.bgApp)
}

#Preview("With Cap") {
    let prefs = Preferences()
    let _ = { prefs.monthlyLimitGB = 25 }()
    return CapRow(preferences: prefs)
        .padding()
        .background(Color.tally.bgApp)
}
