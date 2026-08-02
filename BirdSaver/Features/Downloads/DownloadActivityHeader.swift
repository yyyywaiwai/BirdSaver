import SwiftUI

struct DownloadActivityHeader: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        let metrics = DownloadMetrics(states: viewModel.itemStates)
        let status = statusPresentation

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: status.symbol)
                    .font(.title2)
                    .foregroundStyle(status.color)
                    .frame(width: 42, height: 42)
                    .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(status.title)
                        .font(.title2.bold())
                    Text(viewModel.statusMessage)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: BirdSaverDesign.sectionSpacing)

                if let lastRunAt = viewModel.lastRunAt {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("最終実行")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(lastRunAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.callout.monospacedDigit())
                            .environment(\.locale, Locale(identifier: "ja_JP"))
                    }
                }
            }

            if viewModel.progressTotal > 0 {
                HStack(spacing: 12) {
                    ProgressView(
                        value: Double(viewModel.progressCompleted),
                        total: Double(viewModel.progressTotal)
                    )
                    .progressViewStyle(.linear)

                    Text("\(viewModel.progressCompleted) / \(viewModel.progressTotal)")
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 72, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "全体進捗 \(viewModel.progressCompleted) / \(viewModel.progressTotal)"
                )
            } else if viewModel.isFetchingTimeline {
                ProgressView()
                    .controlSize(.small)
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                DownloadMetricView(
                    title: "走査",
                    value: viewModel.scannedPosts,
                    symbol: "doc.text.magnifyingglass",
                    color: .blue
                )
                DownloadMetricView(
                    title: "保存",
                    value: metrics.succeeded,
                    symbol: "checkmark.circle.fill",
                    color: .green
                )
                DownloadMetricView(
                    title: "スキップ",
                    value: metrics.skipped,
                    symbol: "forward.circle.fill",
                    color: .mint
                )
                DownloadMetricView(
                    title: "失敗",
                    value: metrics.failed,
                    symbol: "exclamationmark.circle.fill",
                    color: .red
                )
            }

            if !viewModel.stopReasonMessage.isEmpty {
                Label(viewModel.stopReasonMessage, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(BirdSaverDesign.contentPadding)
        .background(status.color.opacity(viewModel.isRunning ? 0.06 : 0.025))
    }

    private var statusPresentation: (title: String, symbol: String, color: Color) {
        switch viewModel.runPhase {
        case .fetching:
            return ("メディアを検索しています", "magnifyingglass.circle.fill", .blue)
        case .downloading:
            return ("ダウンロードしています", "arrow.down.circle.fill", .blue)
        case .cancelling:
            return ("キャンセルしています", "xmark.circle.fill", .orange)
        case .completed:
            return ("処理が完了しました", "checkmark.circle.fill", .green)
        case .completedWithFailures:
            return ("確認が必要な項目があります", "exclamationmark.triangle.fill", .red)
        case .empty:
            return ("対象メディアが見つかりませんでした", "tray", .secondary)
        case .cancelled:
            return ("処理を中断しました", "pause.circle.fill", .orange)
        case .failed:
            return ("処理を完了できませんでした", "exclamationmark.octagon.fill", .red)
        case .idle:
            if !viewModel.isAuthenticated {
                return ("Xアカウントを接続してください", "person.crop.circle", .secondary)
            }
            if viewModel.configurationIssue != nil {
                return ("取得条件を確認してください", "slider.horizontal.3", .orange)
            }
            return ("取得の準備ができました", "tray.and.arrow.down.fill", .secondary)
        }
    }
}
