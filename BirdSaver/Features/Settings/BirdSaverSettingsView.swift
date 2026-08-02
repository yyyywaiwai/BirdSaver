import SwiftUI

struct BirdSaverSettingsView: View {
    @ObservedObject var viewModel: BirdSaverViewModel
    @State private var isConfirmingAuthRemoval = false
    @State private var isShowingLogin = false

    var body: some View {
        Form {
            Section("ダウンロード") {
                LabeledContent("最大投稿数") {
                    HStack(spacing: 8) {
                        TextField(
                            "最大投稿数",
                            value: $viewModel.maxPosts,
                            format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 90)

                        Stepper(
                            "最大投稿数",
                            value: $viewModel.maxPosts,
                            in: 1...DownloadConfig.maxPostLimit,
                            step: 50
                        )
                        .labelsHidden()
                    }
                }

                Text("1回の取得で走査する投稿数の上限です。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                LabeledContent("同時ダウンロード数") {
                    HStack(spacing: 8) {
                        TextField(
                            "同時ダウンロード数",
                            value: $viewModel.maxConcurrentDownloads,
                            format: .number
                        )
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .frame(width: 64)

                        Stepper(
                            "同時ダウンロード数",
                            value: $viewModel.maxConcurrentDownloads,
                            in: 1...8
                        )
                        .labelsHidden()
                    }
                }

                Text("回線や保存先の速度に合わせて1〜8件で調整できます。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("保存先") {
                Text(viewModel.baseDirectoryURL.path)
                    .font(.callout.monospaced())
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                HStack {
                    Button("保存先を変更", systemImage: "folder.badge.plus") {
                        chooseBaseDirectory()
                    }

                    Button("既定に戻す", action: viewModel.resetBaseDirectoryToDefault)

                    Spacer()

                    Button("Finderで開く", systemImage: "folder") {
                        WorkspaceFileActions.reveal(viewModel.baseDirectoryURL)
                    }
                }
            }

            Section("Xアカウント") {
                LabeledContent("状態") {
                    Label(
                        viewModel.authStatusText,
                        systemImage: viewModel.isAuthenticated
                            ? "checkmark.seal.fill"
                            : "person.crop.circle.badge.exclamationmark"
                    )
                    .foregroundStyle(viewModel.isAuthenticated ? .green : .secondary)
                }

                HStack {
                    Button(viewModel.isAuthenticated ? "再ログイン" : "ログイン") {
                        isShowingLogin = true
                    }

                    Spacer()

                    Button("認証情報を削除", role: .destructive) {
                        isConfirmingAuthRemoval = true
                    }
                    .disabled(viewModel.isRunning)
                    .confirmationDialog(
                        "保存済みのX認証情報を削除しますか？",
                        isPresented: $isConfirmingAuthRemoval,
                        titleVisibility: .visible
                    ) {
                        Button("認証情報を削除", role: .destructive) {
                            viewModel.clearAuth()
                        }
                        Button("キャンセル", role: .cancel) {}
                    } message: {
                        Text("Keychainの認証情報とXのWebセッションを削除します。次回の取得時に、もう一度ログインが必要になります。")
                    }
                }

                Text("Cookieやトークンをソースコードや設定ファイルには保存しません。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if viewModel.isRunning {
                Section {
                    Label(
                        "変更内容は現在の処理には反映されず、次回の取得から使用されます。",
                        systemImage: "info.circle"
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 560)
        .onDisappear(perform: viewModel.savePreferences)
        .sheet(isPresented: $isShowingLogin) {
            XLoginSheetView(viewModel: viewModel)
        }
    }

    private func chooseBaseDirectory() {
        guard let directory = WorkspaceFileActions.chooseDirectory(
            startingAt: viewModel.baseDirectoryURL
        ) else {
            return
        }
        viewModel.updateBaseDirectory(directory)
    }
}
