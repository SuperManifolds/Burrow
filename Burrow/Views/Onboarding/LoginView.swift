import SwiftUI

/// Account number entry view for first-launch or re-authentication.
struct LoginView: View {
    @ObservedObject var accountViewModel: AccountViewModel
    @State private var iconBreathing = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

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

            AccountNumberField(accountViewModel: accountViewModel)

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
                LoginProgressView(currentStep: accountViewModel.loginStep)
            } else {
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
