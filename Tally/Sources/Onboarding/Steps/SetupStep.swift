import SwiftUI

struct SetupStep: View {
    @Bindable var preferences: Preferences
    @State private var localCap: Int = 20
    @State private var isUnlimited: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Banner Art
            ZStack {
                Color.tally.brand50
                Image(systemName: "calendar.badge.clock")
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
                Text("第 3 步 / 共 3 步")
                    .font(.tally.micro)
                    .tracking(Font.tallyTracking.caps)
                    .foregroundStyle(Color.tally.fg3)
                
                Text("設定一下")
                    .font(.tally.title1)
                    .tracking(Font.tallyTracking.title1)
                    .foregroundStyle(Color.tally.fg1)
                
                Text("稍微告訴 Tally 你的網路方案，這樣才能算出剩餘額度。等一下還可以從「設定」改。")
                    .font(.tally.body)
                    .tracking(Font.tallyTracking.body)
                    .foregroundStyle(Color.tally.fg2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Form Container
                VStack(spacing: 0) {
                    // Start Day Picker Row
                    HStack {
                        Text("每月從幾號開始算")
                            .font(.tally.bodyEm)
                            .tracking(Font.tallyTracking.body)
                            .foregroundStyle(Color.tally.fg1)
                        
                        Spacer()
                        
                        Picker("", selection: $preferences.cycleStartDay) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day) 號").tag(day)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 100)
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s3)
                    
                    Divider()
                        .background(Color.tally.divider)
                        .padding(.horizontal, Spacing.s4)
                    
                    // Cap Limit Stepper Row
                    HStack {
                        Text("每月可以用多少")
                            .font(.tally.bodyEm)
                            .tracking(Font.tallyTracking.body)
                            .foregroundStyle(Color.tally.fg1)
                        
                        Spacer()
                        
                        HStack(spacing: Spacing.s3) {
                            // Checkbox for "Unlimited"
                            Toggle("我沒有上限，只想追蹤", isOn: $isUnlimited)
                                .toggleStyle(CheckboxToggleStyle())
                                .font(.tally.callout)
                                .tracking(Font.tallyTracking.callout)
                                .onChange(of: isUnlimited) { _, newValue in
                                    if newValue {
                                        preferences.monthlyLimitGB = nil
                                    } else {
                                        preferences.monthlyLimitGB = Double(localCap)
                                    }
                                }
                            
                            // Stepper (only interactive if limit is not nil/unlimited)
                            HStack(spacing: 0) {
                                Button(action: {
                                    if localCap > 1 {
                                        localCap -= 1
                                        if !isUnlimited {
                                            preferences.monthlyLimitGB = Double(localCap)
                                        }
                                    }
                                }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 9, weight: .bold))
                                        .frame(width: 22, height: 22)
                                        .background(Color.tally.bgHover)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                
                                Text("\(localCap) GB")
                                    .font(.tally.body.bold())
                                    .tracking(Font.tallyTracking.body)
                                    .foregroundStyle(isUnlimited ? Color.tally.fg4 : Color.tally.fg1)
                                    .frame(width: 54, alignment: .center)
                                
                                Button(action: {
                                    localCap += 1
                                    if !isUnlimited {
                                        preferences.monthlyLimitGB = Double(localCap)
                                    }
                                }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .bold))
                                        .frame(width: 22, height: 22)
                                        .background(Color.tally.bgHover)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, Spacing.s2)
                            .padding(.vertical, Spacing.s1)
                            .background(isUnlimited ? Color.tally.bgApp : Color.tally.bgCardAlt)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.r6)
                                    .stroke(Color.tally.border, lineWidth: 1)
                            )
                            .opacity(isUnlimited ? 0.4 : 1.0)
                            .disabled(isUnlimited)
                        }
                    }
                    .padding(.horizontal, Spacing.s4)
                    .padding(.vertical, Spacing.s3)
                }
                .background(Color.tally.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: Radius.r8))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.r8)
                        .stroke(Color.tally.border, lineWidth: 1)
                )
            }
            .padding(.horizontal, 30)
            .padding(.top, 26)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: 0)
        }
        .onAppear {
            // Initialize local states from preferences
            if let limit = preferences.monthlyLimitGB {
                localCap = Int(limit)
                isUnlimited = false
            } else {
                localCap = 20
                isUnlimited = true
            }
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            HStack(spacing: Spacing.s2) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(configuration.isOn ? Color.tally.accent : Color.tally.fg3)
                configuration.label
                    .foregroundStyle(Color.tally.fg2)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SetupStep(preferences: Preferences())
        .frame(width: 540, height: 460)
        .background(Color.tally.bgCard)
}
