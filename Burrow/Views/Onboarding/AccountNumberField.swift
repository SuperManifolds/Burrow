import SwiftUI

/// Formatted account number input field with auto-login on valid input.
struct AccountNumberField: View {
    @ObservedObject var accountViewModel: AccountViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 8) {
            TextField(accountViewModel.provider.accountInputPlaceholder, text: $accountViewModel.accountNumber)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .multilineTextAlignment(.leading)
                .fixedSize()
                .frame(maxWidth: .infinity)
                .focused($isFocused)
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
        .onAppear { isFocused = true }
    }
}

#if DEBUG
#Preview {
    AccountNumberField(accountViewModel: AccountViewModel())
        .frame(width: 380)
        .padding()
}
#endif
