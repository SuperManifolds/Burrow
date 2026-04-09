import SwiftUI

/// Animated step-by-step login progress indicator.
struct LoginProgressView: View {
    let currentStep: AccountViewModel.LoginStep

    var body: some View {
        VStack(spacing: 16) {
            ForEach(steps, id: \.step) { item in
                HStack(spacing: 10) {
                    Group {
                        if item.step == currentStep {
                            ProgressView()
                                .controlSize(.small)
                                .transition(.scale.combined(with: .opacity))
                        } else if isStepComplete(item.step) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.accent)
                                .transition(.scale(scale: 0.3).combined(with: .opacity))
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.quaternary)
                        }
                    }
                    .frame(width: 16, height: 16)

                    Text(item.label)
                        .font(.subheadline)
                        .foregroundStyle(
                            isStepComplete(item.step) || item.step == currentStep
                                ? .primary
                                : .tertiary
                        )

                    Spacer()
                }
                .animation(.spring(duration: 0.3), value: currentStep)
            }
        }
        .frame(width: 200)
    }

    private struct StepInfo {
        let step: AccountViewModel.LoginStep
        let label: String
    }

    private var steps: [StepInfo] {
        [
            StepInfo(step: .authenticating, label: String(localized: "Authenticating...")),
            StepInfo(step: .generatingKeys, label: String(localized: "Generating keys...")),
            StepInfo(step: .registeringDevice, label: String(localized: "Registering device...")),
            StepInfo(step: .ready, label: String(localized: "Ready!"))
        ]
    }

    private static let stepOrder: [AccountViewModel.LoginStep] = [
        .authenticating, .generatingKeys, .registeringDevice, .ready
    ]

    private func isStepComplete(_ step: AccountViewModel.LoginStep) -> Bool {
        guard let currentIndex = Self.stepOrder.firstIndex(of: currentStep),
              let stepIndex = Self.stepOrder.firstIndex(of: step) else { return false }
        return stepIndex < currentIndex
    }
}

#if DEBUG
#Preview {
    LoginProgressView(currentStep: .registeringDevice)
        .padding()
}
#endif
