import SwiftUI

/// Account number entry view for first-launch or re-authentication.
struct LoginView: View {
    @ObservedObject var accountViewModel: AccountViewModel

    @FocusState private var isFieldFocused: Bool
    @State private var iconBreathing = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon and title
            VStack(spacing: 12) {
                Image(.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .scaleEffect(iconBreathing ? 1.03 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                        value: iconBreathing
                    )
                    .onAppear { iconBreathing = true }

                Text("Burrow")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Enter your \(accountViewModel.provider.providerName) account number")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Account number field
            VStack(spacing: 8) {
                TextField(accountViewModel.provider.accountInputPlaceholder, text: $accountViewModel.accountNumber)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.leading)
                    .fixedSize()
                    .frame(maxWidth: .infinity)
                    .focused($isFieldFocused)
                    .onChange(of: accountViewModel.accountNumber) { _, newValue in
                        let formatted = accountViewModel.provider.formatAccountInput(newValue)
                        accountViewModel.accountNumber = formatted
                        if accountViewModel.provider.validateAccountInput(formatted)
                            && !accountViewModel.isLoading {
                            Task { await accountViewModel.login() }
                        }
                    }
                    .onSubmit {
                        Task { await accountViewModel.login() }
                    }

                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 40)
            }
            .padding(.horizontal, 40)

            // Error message
            if let error = accountViewModel.error {
                VStack(spacing: 6) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    if accountViewModel.isDeviceLimitError,
                       let url = URL(string: "https://mullvad.net/en/account/devices") {
                        Link("Manage devices on mullvad.net", destination: url)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
            }

            if accountViewModel.loginStep != .idle {
                // Animated login progress
                loginProgress
            } else {
                // Login button
                Button {
                    Task { await accountViewModel.login() }
                } label: {
                    Text("Log In")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(
                    accountViewModel.isLoading
                        || !accountViewModel.provider.validateAccountInput(accountViewModel.accountNumber)
                )
            }

            Spacer()

            HStack(spacing: 4) {
                Text("Don't have an account?")
                    .foregroundStyle(.tertiary)
                if let signupURL = URL(string: "https://mullvad.net/en/account/create") {
                    Link("Sign up", destination: signupURL)
                }
            }
            .font(.caption2)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 380, minHeight: 420)
        .animation(.spring(duration: 0.4), value: accountViewModel.loginStep)
        .onAppear { isFieldFocused = true }
    }

    // MARK: - Login Progress

    private var loginProgress: some View {
        VStack(spacing: 16) {
            ForEach(loginSteps, id: \.step) { item in
                HStack(spacing: 10) {
                    Group {
                        if item.step == accountViewModel.loginStep {
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
                            isStepComplete(item.step) || item.step == accountViewModel.loginStep
                                ? .primary
                                : .tertiary
                        )

                    Spacer()
                }
                .animation(.spring(duration: 0.3), value: accountViewModel.loginStep)
            }
        }
        .frame(width: 200)
    }

    private struct LoginStepInfo {
        let step: AccountViewModel.LoginStep
        let label: String
    }

    private var loginSteps: [LoginStepInfo] {
        [
            LoginStepInfo(step: .authenticating, label: String(localized: "Authenticating...")),
            LoginStepInfo(step: .generatingKeys, label: String(localized: "Generating keys...")),
            LoginStepInfo(step: .registeringDevice, label: String(localized: "Registering device...")),
            LoginStepInfo(step: .ready, label: String(localized: "Ready!"))
        ]
    }

    private var stepOrder: [AccountViewModel.LoginStep] {
        [.authenticating, .generatingKeys, .registeringDevice, .ready]
    }

    private func isStepComplete(_ step: AccountViewModel.LoginStep) -> Bool {
        guard let currentIndex = stepOrder.firstIndex(of: accountViewModel.loginStep),
              let stepIndex = stepOrder.firstIndex(of: step) else { return false }
        return stepIndex < currentIndex
    }

}

#if DEBUG
#Preview("Login") {
    LoginView(accountViewModel: AccountViewModel())
}

#Preview("Registering") {
    LoginView(accountViewModel: AccountViewModel.preview(loggedIn: false, loginStep: .registeringDevice))
}
#endif
