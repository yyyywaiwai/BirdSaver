import SwiftUI

@main
struct BirdSaverApp: App {
    @StateObject private var viewModel = BirdSaverViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
