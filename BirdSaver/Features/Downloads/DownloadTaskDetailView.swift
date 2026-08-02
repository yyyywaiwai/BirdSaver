import SwiftUI

struct DownloadTaskDetailView: View {
    let task: MediaDownloadTask
    let state: DownloadItemState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("選択した項目", systemImage: "doc.text.magnifyingglass")
                        .font(.headline)

                    Spacer()

                    DownloadStateLabel(state: state)
                }

                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                    GridRow {
                        Text("タスクID")
                            .foregroundStyle(.secondary)
                        Text(task.id)
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("投稿ID")
                            .foregroundStyle(.secondary)
                        Text(task.postID)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("メディアID")
                            .foregroundStyle(.secondary)
                        Text(task.mediaID)
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("ユーザーID")
                            .foregroundStyle(.secondary)
                        Text(verbatim: task.authorUserID ?? "不明")
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .accessibilityIdentifier("selected-tweet-user-id")
                    }

                    GridRow {
                        Text("ツイートURL")
                            .foregroundStyle(.secondary)
                        Text(task.postURL.absoluteString)
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                    GridRow {
                        Text("保存先")
                            .foregroundStyle(.secondary)
                        Text(task.targetPath.path)
                            .font(.callout.monospaced())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("ツイート本文")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text(task.postText)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityLabel("ツイート本文")
                        .accessibilityValue(task.postText)
                        .accessibilityIdentifier("selected-tweet-body")
                }

                if case .failed(let reason) = state {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }

                HStack {
                    Link(destination: task.postURL) {
                        Label("Xでツイートを開く", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint("既定のブラウザでこのツイートを開きます")
                    .accessibilityIdentifier("selected-tweet-url-button")

                    Link(destination: task.sourceURL) {
                        Label("元メディアを開く", systemImage: "safari")
                    }

                    Button("Finderで表示", systemImage: "folder") {
                        WorkspaceFileActions.reveal(task.targetPath)
                    }

                    Button("パスをコピー", systemImage: "doc.on.doc") {
                        WorkspaceFileActions.copyToPasteboard(task.targetPath.path)
                    }

                    Spacer()
                }
            }
            .padding(BirdSaverDesign.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.bar)
        .accessibilityIdentifier("download-task-detail-pane")
    }
}
