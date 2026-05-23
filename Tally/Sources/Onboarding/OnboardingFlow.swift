import SwiftUI

struct OnboardingFlow: View {
    @Environment(Preferences.self) private var preferences
    @State private var currentStep = 0
    
    var body: some View {
        ZStack {
            // Blurred, warm backdrop overlay
            Color(red: 20.0 / 255.0, green: 15.0 / 255.0, blue: 8.0 / 255.0)
                .opacity(0.45)
                .ignoresSafeArea()
            
            // Onboarding Card Box
            VStack(spacing: 0) {
                // Step Content Area with smooth transition
                ZStack {
                    switch currentStep {
                    case 0:
                        WelcomeStep()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    case 1:
                        PermissionStep()
                            .transition(.asymmetric(
                                insertion: .move(edge: currentStep > 1 ? .leading : .trailing).combined(with: .opacity),
                                removal: .move(edge: currentStep > 1 ? .trailing : .leading).combined(with: .opacity)
                            ))
                    case 2:
                        SetupStep(preferences: preferences)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    default:
                        EmptyView()
                    }
                }
                .animation(Motion.view, value: currentStep)
                .frame(height: 420)
                
                // Divider
                Divider()
                    .background(Color.tally.divider)
                
                // Action / Navigation Footer Bar
                HStack(spacing: 0) {
                    // Step Dots Indicator
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(i == currentStep ? Color.tally.accent : Color.tally.borderStrong)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.leading, 30)
                    
                    Spacer()
                    
                    // Navigation Buttons
                    HStack(spacing: Spacing.s3) {
                        if currentStep > 0 {
                            Button("上一步") {
                                withAnimation(Motion.hover) {
                                    currentStep -= 1
                                }
                            }
                            .buttonStyle(TallyGhostButtonStyle())
                        }
                        
                        Button(primaryButtonText) {
                            handleNext()
                        }
                        .buttonStyle(TallyPrimaryButtonStyle())
                    }
                    .padding(.trailing, 30)
                }
                .frame(height: 60)
                .background(Color.tally.bgCardAlt)
            }
            .frame(width: 540, height: 480)
            .background(Color.tally.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.tally.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 30, x: 0, y: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.tally.bgApp)
    }
    
    private var primaryButtonText: String {
        switch currentStep {
        case 0:
            return "下一步"
        case 1:
            return "已經批准了"
        case 2:
            return "開始用"
        default:
            return ""
        }
    }
    
    private func handleNext() {
        if currentStep < 2 {
            withAnimation(Motion.hover) {
                currentStep += 1
            }
        } else {
            // Step 3 (Setup Complete) -> Complete onboarding
            withAnimation(Motion.view) {
                preferences.onboardingComplete = true
            }
            Log.ui.info("OnboardingFlow: onboardingComplete set to true. Enjoy Tally!")
        }
    }
}

// Custom button styles for unified design tokens
struct TallyPrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tally.bodyEm)
            .tracking(Font.tallyTracking.body)
            .foregroundStyle(Color.tally.accentOn)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isHovered
                ? (configuration.isPressed ? Color.tally.accentPress : Color.tally.accentHover)
                : Color.tally.accent
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

struct TallyGhostButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tally.bodyEm)
            .tracking(Font.tallyTracking.body)
            .foregroundStyle(isHovered ? Color.tally.fg1 : Color.tally.fg2)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color.tally.bgHover : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: Radius.r6))
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

#Preview {
    OnboardingFlow()
        .environment(Preferences())
}
