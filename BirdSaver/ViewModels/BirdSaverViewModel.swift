import Foundation
import Combine
import XGraphQLkit

@MainActor
final class BirdSaverViewModel: ObservableObject {
    enum ActiveSheet: String, Identifiable {
        case login

        var id: String { rawValue }
    }

    @Published var screenName: String
    @Published var maxPosts: Int
    @Published var activeSheet: ActiveSheet?

    @Published private(set) var authContext: XAuthContext?

    @Published private(set) var isRunning = false
    @Published private(set) var isCancelling = false
    @Published private(set) var statusMessage = "待機中"
    @Published private(set) var stopReasonMessage = ""
    @Published private(set) var scannedPosts = 0

    @Published private(set) var progressCompleted = 0
    @Published private(set) var progressTotal = 0

    @Published private(set) var summary: DownloadSummary = .empty
    @Published private(set) var failures: [DownloadFailure] = []
    @Published private(set) var itemStates: [String: DownloadItemState] = [:]

    @Published private(set) var outputDirectory: URL?
    @Published private(set) var lastRunAt: Date?

    private let authService: AuthService
    private let timelineService: TimelineService
    private let mediaDownloadService: MediaDownloadService
    private let settingsStore: AppSettingsStore

    private var runningTask: Task<Void, Never>?

    init(
        authService: AuthService,
        timelineService: TimelineService,
        mediaDownloadService: MediaDownloadService,
        settingsStore: AppSettingsStore
    ) {
        self.authService = authService
        self.timelineService = timelineService
        self.mediaDownloadService = mediaDownloadService
        self.settingsStore = settingsStore

        screenName = settingsStore.screenName
        maxPosts = settingsStore.maxPosts
        lastRunAt = settingsStore.lastRunAt

        do {
            authContext = try authService.loadAuthContext()
        } catch {
            statusMessage = "認証情報の読み込みに失敗: \(error.localizedDescription)"
        }
    }

    convenience init() {
        self.init(
            authService: AuthService(),
            timelineService: TimelineService(),
            mediaDownloadService: MediaDownloadService(),
            settingsStore: AppSettingsStore()
        )
    }

    var isAuthenticated: Bool {
        authContext != nil
    }

    var authStatusText: String {
        if authContext == nil {
            return "未ログイン"
        }
        return "ログイン済み"
    }

    var progressFraction: Double {
        guard progressTotal > 0 else { return 0 }
        return Double(progressCompleted) / Double(progressTotal)
    }

    func openLogin() {
        activeSheet = .login
    }

    func handleLoginResult(_ result: Result<XAuthContext, Error>) {
        switch result {
        case .success(let context):
            do {
                try authService.saveAuthContext(context)
                authContext = context
                statusMessage = "認証情報を保存しました"
                activeSheet = nil
            } catch {
                statusMessage = "認証情報の保存に失敗: \(error.localizedDescription)"
            }

        case .failure(let error):
            statusMessage = "ログイン情報の取得に失敗: \(error.localizedDescription)"
        }
    }

    func clearAuth() {
        do {
            try authService.clearAuthContext()
            authContext = nil
            statusMessage = "保存済み認証情報を削除しました"
        } catch {
            statusMessage = "認証情報削除に失敗: \(error.localizedDescription)"
        }
    }

    func startDownload() {
        guard !isRunning else { return }

        guard let authContext else {
            statusMessage = "先にXへログインしてください"
            activeSheet = .login
            return
        }

        let normalizedName = normalizeScreenName(screenName)
        guard !normalizedName.isEmpty else {
            statusMessage = "screenName を入力してください"
            return
        }

        let clampedMaxPosts = max(1, min(maxPosts, DownloadConfig.maxPostLimit))
        let config = DownloadConfig(
            screenName: normalizedName,
            maxPosts: clampedMaxPosts,
            includeOwnPostsOnly: true,
            baseDirectory: DownloadConfig.defaultBaseDirectory()
        )

        settingsStore.screenName = normalizedName
        settingsStore.maxPosts = clampedMaxPosts

        resetRunState()
        outputDirectory = config.userDirectory

        isRunning = true
        isCancelling = false
        statusMessage = "投稿一覧を取得中..."

        runningTask = Task {
            await runPipeline(config: config, authContext: authContext)
        }
    }

    func cancelDownload() {
        guard isRunning else { return }
        isCancelling = true
        statusMessage = "キャンセル中..."
        runningTask?.cancel()
    }

    private func runPipeline(config: DownloadConfig, authContext: XAuthContext) async {
        do {
            let timelineResult = try await timelineService.collectMediaTasks(config: config, auth: authContext)
            scannedPosts = timelineResult.scannedPosts
            stopReasonMessage = timelineResult.reachedPostLimit
                ? "投稿上限 \(config.clampedMaxPosts) 件に達したため停止しました"
                : "タイムライン末尾まで取得しました"

            let tasks = timelineResult.tasks
            progressTotal = tasks.count
            itemStates = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, .queued) })
            progressCompleted = 0

            if tasks.isEmpty {
                summary = .empty
                failures = []
                statusMessage = "対象メディアが見つかりませんでした"
                finishRun()
                return
            }

            statusMessage = "メディアをダウンロード中..."
            let summary = await mediaDownloadService.downloadAll(
                tasks: tasks,
                concurrency: 3,
                onUpdate: { [weak self] task, state in
                    await self?.applyStateUpdate(task: task, state: state)
                }
            )

            self.summary = summary
            failures = summary.failures
            statusMessage = isCancelling ? "キャンセルしました" : "完了しました"
            settingsStore.lastRunAt = Date()
            lastRunAt = settingsStore.lastRunAt
        } catch is CancellationError {
            statusMessage = "キャンセルしました"
        } catch {
            statusMessage = "処理に失敗: \(error.localizedDescription)"
        }

        finishRun()
    }

    private func resetRunState() {
        summary = .empty
        failures = []
        itemStates = [:]
        progressCompleted = 0
        progressTotal = 0
        scannedPosts = 0
        stopReasonMessage = ""
    }

    private func finishRun() {
        isRunning = false
        isCancelling = false
        runningTask = nil
        recalculateProgress()
    }

    private func recalculateProgress() {
        progressCompleted = itemStates.values.filter(\.isTerminal).count
    }

    private func applyStateUpdate(task: MediaDownloadTask, state: DownloadItemState) {
        itemStates[task.id] = state
        recalculateProgress()
    }

    private func normalizeScreenName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }
}
