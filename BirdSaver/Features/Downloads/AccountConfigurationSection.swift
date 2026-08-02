import SwiftUI

struct AccountConfigurationSection: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        Section("Xアカウント") {
            HStack(spacing: BirdSaverDesign.compactSpacing) {
                Label(
                    viewModel.authStatusText,
                    systemImage: viewModel.isAuthenticated
                        ? "checkmark.seal.fill"
                        : "person.crop.circle.badge.exclamationmark"
                )
                .foregroundStyle(viewModel.isAuthenticated ? .green : .secondary)

                Spacer()

                Button(viewModel.isAuthenticated ? "再ログイン" : "ログイン") {
                    viewModel.openLogin()
                }
            }

            Text("ログイン情報はこのMacのKeychainに保存されます。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
