import SwiftUI

/// Account number entry view for first-launch or re-authentication.
struct LoginView: View {
    @ObservedObject var accountViewModel: AccountViewModel

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon and title
            VStack(spacing: 12) {
                Image(.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)

                Text("Burrow")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Enter your Mullvad account number")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Account number field
            VStack(spacing: 8) {
                TextField("0000 0000 0000 0000", text: $accountViewModel.accountNumber)
                    .textFieldStyle(.plain)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .focused($isFieldFocused)
                    .onChange(of: accountViewModel.accountNumber) { _, newValue in
                        accountViewModel.accountNumber = formatAccountNumber(newValue)
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
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Login button
            Button {
                Task { await accountViewModel.login() }
            } label: {
                Group {
                    if accountViewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Log In")
                    }
                }
                .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(accountViewModel.isLoading || strippedNumber.count != 16)

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
        .onAppear { isFieldFocused = true }
    }

    // MARK: - Helpers

    private var strippedNumber: String {
        accountViewModel.accountNumber.replacingOccurrences(of: " ", with: "")
    }

    /// Format as groups of 4 digits: "1234 5678 9012 3456"
    private func formatAccountNumber(_ input: String) -> String {
        let digits = input.filter(\.isNumber)
        let limited = String(digits.prefix(16))
        var result = ""
        for (index, char) in limited.enumerated() {
            if index > 0 && index % 4 == 0 {
                result.append(" ")
            }
            result.append(char)
        }
        return result
    }
}

#Preview {
    LoginView(accountViewModel: AccountViewModel())
}
