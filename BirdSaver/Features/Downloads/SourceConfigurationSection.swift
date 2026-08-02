import SwiftUI

struct SourceConfigurationSection: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        Section("取得元") {
            Picker("取得元", selection: $viewModel.downloadSource) {
                ForEach(DownloadSource.allCases) { source in
                    Text(source.title).tag(source)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if viewModel.downloadSource == .userMedia {
                VStack(alignment: .leading, spacing: 6) {
                    Text("ユーザー名またはXのURL")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    TextField(
                        "ユーザー名またはXのURL",
                        text: $viewModel.screenName,
                        prompt: Text("@username または https://x.com/…")
                    )
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                }

                Text("ユーザー名、プロフィールURL、投稿URLに対応しています。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Label(
                    "ログイン中のアカウントに保存したブックマークを取得します。",
                    systemImage: "bookmark.fill"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }
        }
    }
}
