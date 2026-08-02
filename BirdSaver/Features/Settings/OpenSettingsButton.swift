import SwiftUI

struct OpenSettingsButton: View {
    var body: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Label("詳細設定", systemImage: "gearshape")
            }
        } else {
            Button("詳細設定", systemImage: "gearshape") {
                WorkspaceFileActions.openSettings()
            }
        }
    }
}
