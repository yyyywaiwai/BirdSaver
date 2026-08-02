import SwiftUI

struct MediaConfigurationSection: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        Section("保存するメディア") {
            Toggle(isOn: $viewModel.includePhotos) {
                Label("画像", systemImage: "photo.on.rectangle")
            }
            .toggleStyle(.checkbox)

            Toggle(isOn: $viewModel.includeVideos) {
                Label("動画・GIF", systemImage: "play.rectangle")
            }
            .toggleStyle(.checkbox)

            if !viewModel.hasAtLeastOneMediaTarget {
                Label(
                    "1つ以上選択してください",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.callout)
                .foregroundStyle(.orange)
            }
        }
    }
}
