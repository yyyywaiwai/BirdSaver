import SwiftUI

struct DownloadEmptyStateView: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        VStack(spacing: 14) {
            if viewModel.isFetchingTimeline {
                ProgressView()
                    .controlSize(.large)
            } else {
                Image(systemName: emptyStateSymbol)
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Text(emptyStateTitle)
                .font(.title2.bold())

            Text(emptyStateDescription)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)

            if !viewModel.isAuthenticated {
                Button("Xにログイン", systemImage: "person.crop.circle.badge.checkmark") {
                    viewModel.openLogin()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if !viewModel.isRunning {
                Button("取得を開始", systemImage: "arrow.down.circle.fill") {
                    viewModel.startDownload()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.isStartActionEnabled)
            }

            if let issue = viewModel.configurationIssue, !viewModel.isRunning {
                Label(issue, systemImage: "arrow.left")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var emptyStateTitle: String {
        switch viewModel.runPhase {
        case .fetching:
            return "メディアを検索しています"
        case .empty:
            return "対象メディアが見つかりませんでした"
        case .cancelled:
            return "処理をキャンセルしました"
        case .failed:
            return "処理を完了できませんでした"
        case .idle, .downloading, .cancelling, .completed, .completedWithFailures:
            break
        }

        if !viewModel.isAuthenticated {
            return "Xアカウントを接続"
        }
        return "取得の準備をしましょう"
    }

    private var emptyStateDescription: String {
        switch viewModel.runPhase {
        case .fetching:
            return "Xの投稿を走査し、保存できる画像と動画を探しています。"
        case .empty, .cancelled, .failed:
            return viewModel.statusMessage
        case .idle, .downloading, .cancelling, .completed, .completedWithFailures:
            break
        }

        if !viewModel.isAuthenticated {
            return "左側の取得条件を設定し、Xへログインするとメディアを保存できます。"
        }
        return "左側で取得元・メディア・保存先を確認してから取得を開始してください。"
    }

    private var emptyStateSymbol: String {
        switch viewModel.runPhase {
        case .empty:
            return "photo.on.rectangle.angled"
        case .cancelled:
            return "pause.circle"
        case .failed:
            return "exclamationmark.octagon"
        case .idle, .fetching, .downloading, .cancelling, .completed, .completedWithFailures:
            break
        }

        if !viewModel.isAuthenticated {
            return "person.crop.circle.badge.questionmark"
        }
        return "tray.and.arrow.down"
    }
}
