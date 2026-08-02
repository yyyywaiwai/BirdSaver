import SwiftUI

struct BirdSaverToolbar: ToolbarContent {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if viewModel.isRunning {
                Button(role: .destructive, action: viewModel.cancelDownload) {
                    Label("キャンセル", systemImage: "xmark.circle")
                }
                .disabled(viewModel.isCancelling)
                .help("現在の処理をキャンセル")
            }

            Button {
                WorkspaceFileActions.reveal(
                    viewModel.outputDirectory ?? viewModel.baseDirectoryURL
                )
            } label: {
                Label("保存先を開く", systemImage: "folder")
            }
            .help("保存先をFinderで開く")

            Button(action: viewModel.openLogin) {
                Label(
                    viewModel.isAuthenticated ? "Xへ再ログイン" : "Xへログイン",
                    systemImage: viewModel.isAuthenticated
                        ? "person.crop.circle.badge.checkmark"
                        : "person.crop.circle"
                )
            }
            .disabled(viewModel.isRunning)
            .help(viewModel.isAuthenticated ? "Xへ再ログイン" : "Xへログイン")

            OpenSettingsButton()
                .labelStyle(.iconOnly)
                .help("詳細設定")
        }
    }
}
