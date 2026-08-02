import SwiftUI

struct XLoginSheetView: View {
    @ObservedObject var viewModel: BirdSaverViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var loginAttemptID = UUID()
    @State private var loginErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Xへログイン")
                        .font(.headline)
                    Text("認証情報はこのMacのKeychainに安全に保存されます。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("閉じる", action: dismiss.callAsFunction)
                .keyboardShortcut(.cancelAction)
            }
            .padding(BirdSaverDesign.contentPadding)
            .background(.bar)

            Divider()

            if let loginErrorMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("ログイン情報を取得できませんでした")
                            .bold()
                        Text(loginErrorMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    Spacer()

                    Button("再試行", action: retryLogin)
                }
                .padding(12)
                .background(Color.red.opacity(0.06))

                Divider()
            }

            XLoginMacWebView { result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        loginErrorMessage = nil
                        viewModel.handleLoginResult(result)
                        dismiss()
                    case .failure(let error):
                        loginErrorMessage = error.localizedDescription
                        viewModel.handleLoginResult(result)
                    }
                }
            }
            .id(loginAttemptID)
        }
        .frame(minWidth: 780, idealWidth: 920, minHeight: 620, idealHeight: 720)
    }

    private func retryLogin() {
        loginErrorMessage = nil
        loginAttemptID = UUID()
    }
}
