import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 300, ideal: 340)
        } detail: {
            detail
        }
        .navigationTitle("BirdSaver")
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .login:
                loginSheet
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("対象ユーザー") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("screenName", text: $viewModel.screenName)
                            .textFieldStyle(.roundedBorder)

                        Stepper(value: $viewModel.maxPosts, in: 1...DownloadConfig.maxPostLimit, step: 50) {
                            Text("最大投稿数: \(viewModel.maxPosts)")
                        }
                        .monospacedDigit()
                    }
                    .padding(.top, 6)
                }

                GroupBox("認証") {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("状態") {
                            Text(viewModel.authStatusText)
                                .foregroundStyle(viewModel.isAuthenticated ? .green : .secondary)
                        }

                        HStack(spacing: 8) {
                            Button(viewModel.isAuthenticated ? "再ログイン" : "ログイン") {
                                viewModel.openLogin()
                            }

                            Button("保存済み削除", role: .destructive) {
                                viewModel.clearAuth()
                            }
                            .disabled(!viewModel.isAuthenticated)
                        }
                    }
                    .padding(.top, 6)
                }

                GroupBox("実行") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Button("取得して保存") {
                                viewModel.startDownload()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(viewModel.isRunning)

                            Button("キャンセル") {
                                viewModel.cancelDownload()
                            }
                            .buttonStyle(.bordered)
                            .disabled(!viewModel.isRunning)
                        }

                        ProgressView(value: viewModel.progressFraction)
                            .tint(.accentColor)

                        Text("\(viewModel.progressCompleted) / \(viewModel.progressTotal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()

                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)
                }

                Text("m3u8 変換は AVFoundation を使用します（外部 ffmpeg バイナリは不使用）。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ダウンロード結果")
                        .font(.title2.weight(.semibold))

                    if let lastRun = viewModel.lastRunAt {
                        Text("最終実行: \(lastRun.formatted(date: .numeric, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("保存先を開く") {
                    openOutputFolder()
                }
                .disabled(viewModel.outputDirectory == nil)
            }

            HStack(spacing: 10) {
                summaryCard(title: "成功", value: viewModel.summary.succeeded, color: .green)
                summaryCard(title: "スキップ", value: viewModel.summary.skipped, color: .secondary)
                summaryCard(title: "失敗", value: viewModel.summary.failed, color: .red)
                summaryCard(title: "合計", value: viewModel.summary.total, color: .accentColor)
            }

            if !viewModel.stopReasonMessage.isEmpty {
                Text("取得停止理由: \(viewModel.stopReasonMessage)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("走査投稿数: \(viewModel.scannedPosts)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if viewModel.failures.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text("失敗はありません")
                        .font(.headline)
                    Text("エラー一覧はここに表示されます")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.failures) { failure in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(failure.taskID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text(failure.reason)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
    }

    private var loginSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("X ログイン")
                    .font(.headline)
                Spacer()
                Button("閉じる") {
                    viewModel.activeSheet = nil
                }
            }
            .padding()

            Divider()

            XLoginMacWebView { result in
                Task { @MainActor in
                    viewModel.handleLoginResult(result)
                }
            }
        }
        .frame(minWidth: 860, minHeight: 640)
    }

    @ViewBuilder
    private func summaryCard(title: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private func openOutputFolder() {
        guard let directory = viewModel.outputDirectory else { return }
        NSWorkspace.shared.activateFileViewerSelecting([directory])
    }
}
