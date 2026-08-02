import SwiftUI

struct DestinationConfigurationSection: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        Section("保存先") {
            Text(viewModel.baseDirectoryURL.path)
                .font(.callout.monospaced())
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)

            HStack {
                Button("変更", systemImage: "folder.badge.plus") {
                    chooseBaseDirectory()
                }

                Button("既定に戻す", action: viewModel.resetBaseDirectoryToDefault)

                Spacer()

                Button("開く", systemImage: "folder") {
                    WorkspaceFileActions.reveal(viewModel.baseDirectoryURL)
                }
            }
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
