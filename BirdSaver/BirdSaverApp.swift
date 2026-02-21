import SwiftUI

@main
struct BirdSaverApp: App {
    @StateObject private var viewModel = BirdSaverViewModel()
    private enum WindowSize {
        static let minWidth: CGFloat = 900
        static let minHeight: CGFloat = 640
        static let defaultWidth: CGFloat = 1200
        static let defaultHeight: CGFloat = 800
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
                .frame(minWidth: WindowSize.minWidth, minHeight: WindowSize.minHeight)
        }
        .defaultSize(width: WindowSize.defaultWidth, height: WindowSize.defaultHeight)
        .windowResizability(.contentMinSize)
    }
}
