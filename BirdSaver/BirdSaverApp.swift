import SwiftUI

@main
struct BirdSaverApp: App {
    @StateObject private var viewModel = BirdSaverViewModel()

    private enum WindowSize {
        static let minWidth: CGFloat = 980
        static let minHeight: CGFloat = 680
        static let defaultWidth: CGFloat = 1280
        static let defaultHeight: CGFloat = 820
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: WindowSize.minWidth, minHeight: WindowSize.minHeight)
        }
        .defaultSize(width: WindowSize.defaultWidth, height: WindowSize.defaultHeight)
        .windowResizability(.contentMinSize)
        .commands {
            CommandMenu("ダウンロード") {
                if viewModel.isAuthenticated {
                    Button("取得を開始", action: viewModel.startDownload)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(!viewModel.isStartActionEnabled)
                } else {
                    Button("Xにログイン", action: viewModel.openLogin)
                        .keyboardShortcut(.return, modifiers: .command)
                        .disabled(viewModel.isRunning)
                }

                Button("キャンセル", action: viewModel.cancelDownload)
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(!viewModel.isRunning)

                Divider()

                Button("保存先を開く") {
                    WorkspaceFileActions.reveal(
                        viewModel.outputDirectory ?? viewModel.baseDirectoryURL
                    )
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }

        Settings {
            BirdSaverSettingsView(viewModel: viewModel)
        }
    }
}
