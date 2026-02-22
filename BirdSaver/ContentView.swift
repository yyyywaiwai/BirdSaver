import AppKit
import SwiftUI

struct ContentView: View {
  @ObservedObject var viewModel: BirdSaverViewModel

  @State private var isSetupExpanded = true
  @State private var isQueueExpanded = true
  @State private var isSettingsPresented = false

  private let tableVisibleRowCount = 10
  private let queueRowHeight: CGFloat = 34
  private let queueHeaderHeight: CGFloat = 28

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 14) {
          setupSection
          operationSection
          timelineSection
          queueSection
          summarySection
          Spacer(minLength: 0)
        }
        .padding(20)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .navigationTitle("BirdSaver")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button {
            withAnimation(.easeInOut(duration: 0.2)) {
              isSetupExpanded = false
            }
            isSettingsPresented = true
          } label: {
            Image(systemName: "gearshape")
          }
          .help("アプリ設定")
        }
      }
    }
    .animation(.easeInOut(duration: 0.2), value: isSetupExpanded)
    .animation(.easeInOut(duration: 0.2), value: isQueueExpanded)
    .onChange(of: viewModel.isRunning) { isRunning in
      if isRunning {
        withAnimation(.easeInOut(duration: 0.2)) {
          isSetupExpanded = false
          isQueueExpanded = true
        }
      }
    }
    .sheet(item: $viewModel.activeSheet) { sheet in
      switch sheet {
      case .login:
        loginSheet
      }
    }
    .sheet(isPresented: $isSettingsPresented) {
      settingsSheet
    }
  }

  private var setupSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "取得設定", symbol: "square.and.pencil", isExpanded: isSetupExpanded) {
        isSetupExpanded.toggle()
      }

      if isSetupExpanded {
        VStack(alignment: .leading, spacing: 12) {
          setupField(title: "ユーザー名 / ユーザーURL / 投稿URL") {
            TextField("@username または https://x.com/... を入力", text: $viewModel.screenName)
              .textFieldStyle(.roundedBorder)
          }

          setupField(title: "取得対象") {
            HStack(spacing: 16) {
              Toggle(isOn: $viewModel.includePhotos) {
                Label("画像", systemImage: "photo")
              }
              .toggleStyle(.checkbox)

              Toggle(isOn: $viewModel.includeVideos) {
                Label("動画", systemImage: "video")
              }
              .toggleStyle(.checkbox)
            }
          }

          setupField(title: "保存開始") {
            HStack(spacing: 8) {
              Text(viewModel.baseDirectoryURL.path)
                .font(.callout.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)

              Spacer(minLength: 0)

              Button("選択") {
                chooseBaseDirectory()
              }
              .buttonStyle(.bordered)

              Button("既定") {
                viewModel.resetBaseDirectoryToDefault()
              }
              .buttonStyle(.bordered)
            }
          }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(16)
    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
  }

  private var operationSection: some View {
    HStack(spacing: 8) {
      Label(
        viewModel.authStatusText,
        systemImage: viewModel.isAuthenticated ? "checkmark.seal.fill" : "xmark.seal"
      )
      .foregroundStyle(viewModel.isAuthenticated ? .green : .secondary)

      Button(viewModel.isAuthenticated ? "再ログイン" : "ログイン") {
        viewModel.openLogin()
      }
      .buttonStyle(.bordered)

      Button("保存済み削除", role: .destructive) {
        viewModel.clearAuth()
      }
      .buttonStyle(.bordered)
      .disabled(!viewModel.isAuthenticated)

      Spacer()

      Button("保存先を開く") {
        openOutputFolder()
      }
      .buttonStyle(.bordered)
      .disabled(viewModel.outputDirectory == nil)

      Button("キャンセル") {
        viewModel.cancelDownload()
      }
      .buttonStyle(.bordered)
      .disabled(!viewModel.isRunning)

      Button("取得して保存") {
        viewModel.startDownload()
      }
      .buttonStyle(.borderedProminent)
      .disabled(viewModel.isRunning)
    }
  }

  private var timelineSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        if viewModel.isFetchingTimeline {
          ProgressView()
            .controlSize(.small)
        }

        Text(viewModel.timelineStatusText)
          .font(.callout.monospacedDigit())

        Spacer()

        Text(viewModel.statusMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if viewModel.progressTotal > 0 {
        HStack(spacing: 8) {
          LightweightProgressBar(progress: viewModel.progressFraction)
          Text("\(viewModel.progressCompleted) / \(viewModel.progressTotal)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
      }
    }
    .padding(12)
    .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
  }

  private var queueSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      sectionHeader(title: "DLキュー", symbol: "list.bullet.rectangle", isExpanded: isQueueExpanded) {
        isQueueExpanded.toggle()
      }

      if isQueueExpanded {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("待機キュー")
              .font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(viewModel.queuedTaskCount) 個のキュー")
              .font(.callout.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 10)
          .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))

          queueTable(
            title: "DL中",
            taskIDs: viewModel.inFlightTaskIDs,
            reverseOrder: false,
            minimumRowCount: viewModel.maxConcurrentDownloads,
            showEmptyMessage: false,
            emptyMessage: "現在進行中のタスクはありません"
          )

          queueTable(
            title: "処理結果",
            taskIDs: viewModel.finishedTaskIDs,
            reverseOrder: false,
            emptyMessage: "実行後に結果が表示されます"
          )

          if !viewModel.stopReasonMessage.isEmpty {
            Text("停止理由: \(viewModel.stopReasonMessage)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(16)
    .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
  }

  private func queueTable(
    title: String,
    taskIDs: [String],
    reverseOrder: Bool,
    minimumRowCount: Int = 0,
    showEmptyMessage: Bool = true,
    emptyMessage: String
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)

      if taskIDs.isEmpty && showEmptyMessage && minimumRowCount == 0 {
        Text(emptyMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(10)
          .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
      } else {
        let orderedTaskIDs = reverseOrder ? Array(taskIDs.reversed()) : taskIDs
        let displayRowCount = max(orderedTaskIDs.count, minimumRowCount)
        let placeholderRowCount = max(0, displayRowCount - orderedTaskIDs.count)

        VStack(spacing: 0) {
          ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
              Section {
                ForEach(orderedTaskIDs, id: \.self) { taskID in
                  if let row = queueRow(forTaskID: taskID) {
                    QueueTableRow(row: row)
                      .equatable()
                      .frame(height: queueRowHeight)
                  }
                }

                ForEach(0..<placeholderRowCount, id: \.self) { _ in
                  QueueTablePlaceholderRow()
                    .frame(height: queueRowHeight)
                }
              } header: {
                VStack(spacing: 0) {
                  queueHeaderRow
                    .background(.background.opacity(0.85))
                  Divider()
                }
              }
            }
          }
          .frame(height: tableHeight(for: displayRowCount) + queueHeaderHeight + 1)
          .clipped()
        }
        .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
        .transaction { transaction in
          transaction.animation = nil
        }
      }
    }
  }

  private func queueRow(forTaskID taskID: String) -> QueueDisplayRow? {
    guard let task = viewModel.task(for: taskID) else {
      return nil
    }
    return QueueDisplayRow(task: task, state: viewModel.state(forTaskID: taskID))
  }

  private var summarySection: some View {
    let counts = displayedSummaryCounts
    let isSummaryRunning = viewModel.progressTotal > 0 && counts.total < viewModel.progressTotal

    return VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        summaryBadge(title: "OK", value: counts.succeeded, color: .green)
        summaryBadge(title: "SKIP", value: counts.skipped, color: .secondary)
        summaryBadge(title: "NG", value: counts.failed, color: .red)
        summaryBadge(
          title: "TOTAL", value: counts.total, color: .accentColor, isLive: isSummaryRunning)
      }

      if isSummaryRunning {
        HStack(spacing: 10) {
          ProgressView(value: Double(counts.total), total: Double(viewModel.progressTotal))
            .progressViewStyle(.linear)
            .frame(maxWidth: 300)

          Text("処理中: \(counts.total) / \(viewModel.progressTotal)")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
      }

      HStack {
        Text("走査投稿数: \(viewModel.scannedPosts)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .monospacedDigit()

        Spacer()

        if let lastRun = viewModel.lastRunAt {
          Text("最終実行: \(lastRun.formatted(date: .numeric, time: .shortened))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var displayedSummaryCounts: SummaryCounts {
    let live = liveSummaryCounts

    if viewModel.isRunning {
      return live
    }

    let final = SummaryCounts(
      succeeded: viewModel.summary.succeeded,
      skipped: viewModel.summary.skipped,
      failed: viewModel.summary.failed,
      total: viewModel.summary.total
    )

    if final.total == 0, live.total > 0 {
      return live
    }

    return final
  }

  private var liveSummaryCounts: SummaryCounts {
    var succeeded = 0
    var skipped = 0
    var failed = 0

    for state in viewModel.itemStates.values {
      switch state {
      case .succeeded:
        succeeded += 1
      case .skipped:
        skipped += 1
      case .failed:
        failed += 1
      case .queued, .downloading, .converting:
        break
      }
    }

    return SummaryCounts(
      succeeded: succeeded,
      skipped: skipped,
      failed: failed,
      total: succeeded + skipped + failed
    )
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

  private var settingsSheet: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("アプリ設定")
        .font(.title3.weight(.semibold))

      HStack(spacing: 8) {
        Text("最大投稿数:")
        TextField("最大投稿数", value: $viewModel.maxPosts, format: .number)
          .textFieldStyle(.roundedBorder)
          .frame(width: 80)
          .multilineTextAlignment(.trailing)
          .monospacedDigit()
          .onChange(of: viewModel.maxPosts) { newValue in
            if newValue > DownloadConfig.maxPostLimit {
              viewModel.maxPosts = DownloadConfig.maxPostLimit
            } else if newValue < 1 {
              viewModel.maxPosts = 1
            }
          }
        Stepper("", value: $viewModel.maxPosts, in: 1...DownloadConfig.maxPostLimit, step: 50)
          .labelsHidden()
      }

      HStack(spacing: 8) {
        Text("DL並列数:")
        TextField("DL並列数", value: $viewModel.maxConcurrentDownloads, format: .number)
          .textFieldStyle(.roundedBorder)
          .frame(width: 50)
          .multilineTextAlignment(.trailing)
          .monospacedDigit()
          .onChange(of: viewModel.maxConcurrentDownloads) { newValue in
            if newValue > 8 {
              viewModel.maxConcurrentDownloads = 8
            } else if newValue < 1 {
              viewModel.maxConcurrentDownloads = 1
            }
          }
        Stepper("", value: $viewModel.maxConcurrentDownloads, in: 1...8)
          .labelsHidden()
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("保存先")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(viewModel.baseDirectoryURL.path)
          .font(.callout.monospaced())
          .lineLimit(2)
          .truncationMode(.middle)
      }

      HStack(spacing: 8) {
        Button("保存先を選択") {
          chooseBaseDirectory()
        }

        Button("既定に戻す") {
          viewModel.resetBaseDirectoryToDefault()
        }

        Spacer()

        Button("閉じる") {
          isSettingsPresented = false
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: 520)
  }

  private func setupField<Content: View>(
    title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      content()
    }
  }

  private func sectionHeader(
    title: String,
    symbol: String,
    isExpanded: Bool,
    toggle: @escaping () -> Void
  ) -> some View {
    Button(action: toggle) {
      HStack {
        Label(title, systemImage: symbol)
          .font(.headline)
        Spacer()
        Image(systemName: "chevron.down")
          .font(.caption.weight(.semibold))
          .rotationEffect(.degrees(isExpanded ? 0 : -90))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var queueHeaderRow: some View {
    HStack(spacing: QueueTableLayout.columnSpacing) {
      Text("ID")
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("種別")
        .frame(width: QueueTableLayout.kindWidth, alignment: .center)
      Text("状態")
        .frame(width: QueueTableLayout.stateWidth, alignment: .center)
      HStack(spacing: 8) {
        Text("進捗")
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("100%")
          .font(.caption.monospacedDigit())
          .hidden()
          .frame(width: QueueTableLayout.progressValueWidth, alignment: .trailing)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      Text("S")
        .font(.caption.bold())
        .frame(width: QueueTableLayout.statusWidth, alignment: .center)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 10)
    .frame(height: queueHeaderHeight)
  }

  private struct SummaryCounts {
    let succeeded: Int
    let skipped: Int
    let failed: Int
    let total: Int
  }

  private func tableHeight(for rowCount: Int) -> CGFloat {
    CGFloat(min(max(rowCount, 1), tableVisibleRowCount)) * queueRowHeight
  }

  private func summaryBadge(
    title: String,
    value: Int,
    color: Color,
    isLive: Bool = false
  ) -> some View {
    HStack(spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("\(value)")
        .font(.body.monospacedDigit().weight(.semibold))
        .foregroundStyle(color)
      if isLive {
        ProgressView()
          .controlSize(.small)
          .scaleEffect(0.7)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(.quaternary.opacity(0.35), in: Capsule())
  }

  private func chooseBaseDirectory() {
    let panel = NSOpenPanel()
    panel.prompt = "選択"
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    panel.directoryURL = viewModel.baseDirectoryURL

    if panel.runModal() == .OK, let directory = panel.url {
      viewModel.updateBaseDirectory(directory)
    }
  }

  private func openOutputFolder() {
    guard let directory = viewModel.outputDirectory else { return }
    NSWorkspace.shared.activateFileViewerSelecting([directory])
  }
}

private enum QueueTableLayout {
  static let columnSpacing: CGFloat = 10
  static let kindWidth: CGFloat = 70
  static let stateWidth: CGFloat = 100
  static let progressValueWidth: CGFloat = 40
  static let statusWidth: CGFloat = 26
}

private struct LightweightProgressBar: View {
  let progress: Double

  var body: some View {
    GeometryReader { proxy in
      let clamped = max(0, min(1, progress))
      let fillWidth = proxy.size.width * clamped

      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.secondary.opacity(0.2))
        Capsule()
          .fill(Color.accentColor)
          .frame(width: fillWidth)
      }
    }
    .frame(height: 6)
    .transaction { transaction in
      transaction.animation = nil
    }
  }
}

private struct QueueTableRow: View, Equatable {
  let row: QueueDisplayRow

  static func == (lhs: QueueTableRow, rhs: QueueTableRow) -> Bool {
    lhs.row == rhs.row
  }

  var body: some View {
    HStack(spacing: QueueTableLayout.columnSpacing) {
      Text(row.task.id)
        .font(.caption.monospaced())
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(row.kindLabel)
        .font(.caption)
        .frame(width: QueueTableLayout.kindWidth, alignment: .center)

      Text(row.stateLabel)
        .font(.caption)
        .frame(width: QueueTableLayout.stateWidth, alignment: .center)

      HStack(spacing: 8) {
        LightweightProgressBar(progress: row.progressValue)
        Text(row.progressText)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          .frame(width: QueueTableLayout.progressValueWidth, alignment: .trailing)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Image(systemName: row.statusSymbol)
        .foregroundStyle(row.statusColor)
        .frame(width: QueueTableLayout.statusWidth, alignment: .center)
    }
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }
}

private struct QueueTablePlaceholderRow: View {
  var body: some View {
    HStack(spacing: QueueTableLayout.columnSpacing) {
      Color.clear
        .frame(maxWidth: .infinity)

      Color.clear
        .frame(width: QueueTableLayout.kindWidth)

      Color.clear
        .frame(width: QueueTableLayout.stateWidth)

      HStack(spacing: 8) {
        Capsule()
          .fill(Color.secondary.opacity(0.08))
          .frame(height: 6)
        Text(" ")
          .font(.caption.monospacedDigit())
          .frame(width: QueueTableLayout.progressValueWidth, alignment: .trailing)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      Color.clear
        .frame(width: QueueTableLayout.statusWidth)
    }
    .padding(.horizontal, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .bottom) {
      Divider()
    }
  }
}

private struct QueueDisplayRow: Identifiable, Equatable {
  let task: MediaDownloadTask
  let state: DownloadItemState

  var id: String { task.id }

  var kindLabel: String {
    switch task.kind {
    case .photo:
      return "画像"
    case .video, .animatedGif:
      return "動画"
    }
  }

  var stateLabel: String {
    switch state {
    case .queued:
      return "待機"
    case .downloading:
      return "取得中"
    case .converting:
      return "変換中"
    case .succeeded:
      return "完了"
    case .skipped:
      return "スキップ"
    case .failed:
      return "失敗"
    }
  }

  var progressValue: Double {
    switch state {
    case .queued:
      return 0
    case .downloading:
      return 0.4
    case .converting:
      return 0.75
    case .succeeded, .skipped, .failed:
      return 1
    }
  }

  var progressText: String {
    "\(Int(progressValue * 100))%"
  }

  var statusSymbol: String {
    switch state {
    case .queued:
      return "clock"
    case .downloading:
      return "arrow.down.circle"
    case .converting:
      return "gearshape.2"
    case .succeeded:
      return "checkmark.circle.fill"
    case .skipped:
      return "forward.circle.fill"
    case .failed:
      return "xmark.circle.fill"
    }
  }

  var statusColor: Color {
    switch state {
    case .queued:
      return .secondary
    case .downloading:
      return .blue
    case .converting:
      return .orange
    case .succeeded:
      return .green
    case .skipped:
      return .mint
    case .failed:
      return .red
    }
  }
}
