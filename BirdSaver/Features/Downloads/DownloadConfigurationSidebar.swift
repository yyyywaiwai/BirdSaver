import SwiftUI

struct DownloadConfigurationSidebar: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        VStack(spacing: 0) {
            Form {
                AccountConfigurationSection(viewModel: viewModel)
                SourceConfigurationSection(viewModel: viewModel)
                MediaConfigurationSection(viewModel: viewModel)
                DestinationConfigurationSection(viewModel: viewModel)
            }
            .formStyle(.grouped)
            .disabled(viewModel.isRunning)

            Divider()

            RunActionFooter(viewModel: viewModel)
        }
        .navigationTitle("BirdSaver")
    }
}
