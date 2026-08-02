import SwiftUI

struct DownloadTaskTable: View {
    let tasks: [MediaDownloadTask]
    let states: [String: DownloadItemState]
    @Binding var selection: String?

    var body: some View {
        Table(tasks, selection: $selection) {
            TableColumn("ツイート") { task in
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.postText)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .accessibilityIdentifier("tweet-body-\(task.id)")

                    Text(verbatim: "ユーザーID \(task.authorUserID ?? "不明")  •  投稿ID \(task.postID)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityIdentifier("tweet-user-id-\(task.id)")
                }
                .help(task.postText)
            }
            .width(min: 220, ideal: 320)

            TableColumn("ツイートURL") { task in
                Link(destination: task.postURL) {
                    Label("開く", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(task.postURL.absoluteString)
                .accessibilityLabel("ツイートを開く")
                .accessibilityHint("既定のブラウザでこのツイートを開きます")
                .accessibilityIdentifier("tweet-url-button-\(task.id)")
            }
            .width(min: 88, ideal: 102, max: 116)

            TableColumn("種別") { task in
                Label(mediaTitle(for: task.kind), systemImage: mediaSymbol(for: task.kind))
                    .labelStyle(.titleAndIcon)
            }
            .width(min: 70, ideal: 82, max: 100)

            TableColumn("状態") { task in
                DownloadStateLabel(state: states[task.id] ?? .queued)
            }
            .width(min: 82, ideal: 104, max: 130)

            TableColumn("保存ファイル") { task in
                Text(task.targetPath.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(task.targetPath.path)
            }
            .width(min: 130, ideal: 220)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func mediaTitle(for kind: MediaDownloadKind) -> String {
        switch kind {
        case .photo:
            return "画像"
        case .video:
            return "動画"
        case .animatedGif:
            return "GIF"
        }
    }

    private func mediaSymbol(for kind: MediaDownloadKind) -> String {
        switch kind {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .animatedGif:
            return "sparkles.tv"
        }
    }
}
