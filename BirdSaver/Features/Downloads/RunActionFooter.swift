import SwiftUI

struct RunActionFooter: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: BirdSaverDesign.compactSpacing) {
                Label("最大 \(viewModel.maxPosts) 投稿", systemImage: "text.badge.checkmark")
                    .lineLimit(1)

                Spacer()

                OpenSettingsButton()
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            if viewModel.isRunning {
                Label(
                    "実行中は取得条件を変更できません",
                    systemImage: "lock.fill"
                )
                .font(.callout)
                .foregroundStyle(.secondary)

                Button(role: .destructive, action: viewModel.cancelDownload) {
                    Label(
                        viewModel.isCancelling ? "キャンセル中…" : "キャンセル",
                        systemImage: "xmark.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(viewModel.isCancelling)
            } else {
                if let issue = viewModel.configurationIssue {
                    Label(issue, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !viewModel.isAuthenticated {
                    Label(
                        "開始時にXへログインします",
                        systemImage: "person.crop.circle.badge.questionmark"
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                Button(action: viewModel.performPrimaryAction) {
                    Label(
                        viewModel.startActionTitle,
                        systemImage: viewModel.isAuthenticated
                            ? "arrow.down.circle.fill"
                            : "person.crop.circle.badge.checkmark"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isAuthenticated && !viewModel.isStartActionEnabled)
            }
        }
        .padding(BirdSaverDesign.contentPadding)
        .background(.bar)
    }
}
