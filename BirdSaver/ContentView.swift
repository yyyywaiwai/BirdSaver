import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        NavigationSplitView {
            DownloadConfigurationSidebar(viewModel: viewModel)
                .navigationSplitViewColumnWidth(
                    min: BirdSaverDesign.sidebarMinimumWidth,
                    ideal: BirdSaverDesign.sidebarIdealWidth,
                    max: BirdSaverDesign.sidebarMaximumWidth
                )
        } detail: {
            DownloadActivityView(viewModel: viewModel)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            BirdSaverToolbar(viewModel: viewModel)
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .login:
                XLoginSheetView(viewModel: viewModel)
            }
        }
    }
}
