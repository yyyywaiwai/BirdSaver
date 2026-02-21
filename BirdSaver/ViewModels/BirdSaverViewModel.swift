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
    @Published var includePhotos: Bool
    @Published var includeVideos: Bool
    @Published var maxConcurrentDownloads: Int
    @Published var baseDirectoryURL: URL
    @Published var activeSheet: ActiveSheet?

    @Published private(set) var authContext: XAuthContext?

    @Published private(set) var isRunning = false
    @Published private(set) var isCancelling = false
    @Published private(set) var isFetchingTimeline = false
    @Published private(set) var statusMessage = "待機中"
    @Published private(set) var stopReasonMessage = ""
    @Published private(set) var scannedPosts = 0
    @Published private(set) var timelineCollectedTaskCount = 0

    @Published private(set) var progressCompleted = 0
    @Published private(set) var progressTotal = 0

    @Published private(set) var summary: DownloadSummary = .empty
    @Published private(set) var failures: [DownloadFailure] = []
    @Published private(set) var downloadTasks: [MediaDownloadTask] = []
    @Published private(set) var itemStates: [String: DownloadItemState] = [:]

    @Published private(set) var queuedTaskCount = 0
    @Published private(set) var inFlightTaskIDs: [String] = []
    @Published private(set) var finishedTaskIDs: [String] = []

    @Published private(set) var outputDirectory: URL?
    @Published private(set) var lastRunAt: Date?

    private let authService: AuthService
    private let timelineService: TimelineService
    private let mediaDownloadService: MediaDownloadService
    private let settingsStore: AppSettingsStore

    private var runningTask: Task<Void, Never>?
    private var taskByID: [String: MediaDownloadTask] = [:]
    private var inFlightTaskIDSet = Set<String>()
    private var finishedTaskIDSet = Set<String>()
    private var pendingStateUpdates: [String: (MediaDownloadTask, DownloadItemState)] = [:]
    private var pendingFlushTask: Task<Void, Never>?

    private static let uiFlushIntervalNanos: UInt64 = 80_000_000

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
        includePhotos = settingsStore.includePhotos
        includeVideos = settingsStore.includeVideos
        maxConcurrentDownloads = settingsStore.maxConcurrentDownloads
        baseDirectoryURL = settingsStore.baseDirectoryURL
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

    var hasAtLeastOneMediaTarget: Bool {
        includePhotos || includeVideos
    }

    var timelineStatusText: String {
        if isFetchingTimeline {
            return "タイムライン取得中: 走査 \(scannedPosts)件 / キュー \(timelineCollectedTaskCount)件"
        }

        if scannedPosts > 0 || progressTotal > 0 {
            return "タイムライン取得: 走査 \(scannedPosts)件 / キュー \(progressTotal)件"
        }

        return "タイムライン未取得"
    }

    func task(for id: String) -> MediaDownloadTask? {
        taskByID[id]
    }

    func state(forTaskID id: String) -> DownloadItemState {
        itemStates[id] ?? .queued
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

    func updateBaseDirectory(_ url: URL) {
        baseDirectoryURL = url.standardizedFileURL
        settingsStore.baseDirectoryURL = baseDirectoryURL
        statusMessage = "保存先を更新しました"
    }

    func resetBaseDirectoryToDefault() {
        updateBaseDirectory(DownloadConfig.defaultBaseDirectory())
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

        guard hasAtLeastOneMediaTarget else {
            statusMessage = "取得対象を1つ以上選択してください"
            return
        }

        let clampedMaxPosts = max(1, min(maxPosts, DownloadConfig.maxPostLimit))
        let clampedConcurrency = max(1, min(maxConcurrentDownloads, 8))
        let normalizedBaseDirectory = baseDirectoryURL.standardizedFileURL
        let config = DownloadConfig(
            screenName: normalizedName,
            maxPosts: clampedMaxPosts,
            includeOwnPostsOnly: true,
            includePhotos: includePhotos,
            includeVideos: includeVideos,
            baseDirectory: normalizedBaseDirectory
        )

        settingsStore.screenName = normalizedName
        settingsStore.maxPosts = clampedMaxPosts
        settingsStore.includePhotos = includePhotos
        settingsStore.includeVideos = includeVideos
        settingsStore.maxConcurrentDownloads = clampedConcurrency
        settingsStore.baseDirectoryURL = normalizedBaseDirectory

        resetRunState()
        outputDirectory = config.userDirectory

        isRunning = true
        isCancelling = false
        isFetchingTimeline = true
        statusMessage = "タイムラインを取得中..."

        runningTask = Task {
            await runPipeline(
                config: config,
                authContext: authContext,
                concurrency: clampedConcurrency
            )
        }
    }

    func cancelDownload() {
        guard isRunning else { return }
        isCancelling = true
        statusMessage = "キャンセル中..."
        runningTask?.cancel()
    }

    private func runPipeline(config: DownloadConfig, authContext: XAuthContext, concurrency: Int) async {
        do {
            let timelineResult = try await timelineService.collectMediaTasks(
                config: config,
                auth: authContext,
                onProgress: { [weak self] progress in
                    await self?.applyTimelineProgress(progress)
                }
            )

            isFetchingTimeline = false
            scannedPosts = timelineResult.scannedPosts
            timelineCollectedTaskCount = timelineResult.tasks.count
            stopReasonMessage = timelineResult.reachedPostLimit
                ? "投稿上限 \(config.clampedMaxPosts) 件に達したため停止しました"
                : "タイムライン末尾まで取得しました"

            let tasks = timelineResult.tasks
            prepareQueueState(with: tasks)

            if tasks.isEmpty {
                summary = .empty
                failures = []
                statusMessage = "対象条件に一致するメディアが見つかりませんでした"
                finishRun()
                return
            }

            statusMessage = "メディアをダウンロード中..."
            let summary = await mediaDownloadService.downloadAll(
                tasks: tasks,
                concurrency: concurrency,
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

    private func applyTimelineProgress(_ progress: TimelineFetchProgress) {
        scannedPosts = progress.scannedPosts
        timelineCollectedTaskCount = progress.collectedTasks
        if isFetchingTimeline {
            statusMessage = "タイムラインを取得中..."
        }
    }

    private func prepareQueueState(with tasks: [MediaDownloadTask]) {
        downloadTasks = tasks
        taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        itemStates = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, .queued) })
        progressTotal = tasks.count
        progressCompleted = 0

        queuedTaskCount = tasks.count
        inFlightTaskIDs = []
        finishedTaskIDs = []
        inFlightTaskIDSet.removeAll(keepingCapacity: true)
        finishedTaskIDSet.removeAll(keepingCapacity: true)
    }

    private func resetRunState() {
        pendingFlushTask?.cancel()
        pendingFlushTask = nil
        pendingStateUpdates = [:]

        summary = .empty
        failures = []
        downloadTasks = []
        taskByID = [:]

        itemStates = [:]
        progressCompleted = 0
        progressTotal = 0

        queuedTaskCount = 0
        inFlightTaskIDs = []
        finishedTaskIDs = []
        inFlightTaskIDSet.removeAll(keepingCapacity: true)
        finishedTaskIDSet.removeAll(keepingCapacity: true)

        scannedPosts = 0
        timelineCollectedTaskCount = 0
        stopReasonMessage = ""
        isFetchingTimeline = false
    }

    private func finishRun() {
        flushPendingStateUpdatesNow()
        isFetchingTimeline = false
        isRunning = false
        isCancelling = false
        runningTask = nil
    }

    private enum QueueBucket {
        case queued
        case inFlight
        case finished
    }

    private func bucket(for state: DownloadItemState) -> QueueBucket {
        switch state {
        case .queued:
            return .queued
        case .downloading, .converting:
            return .inFlight
        case .succeeded, .skipped, .failed:
            return .finished
        }
    }

    private func applyStateUpdate(task: MediaDownloadTask, state: DownloadItemState) {
        pendingStateUpdates[task.id] = (task, state)
        scheduleFlushIfNeeded()
    }

    private func scheduleFlushIfNeeded() {
        guard pendingFlushTask == nil else { return }
        pendingFlushTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: Self.uiFlushIntervalNanos)
            self.flushPendingStateUpdates()
        }
    }

    private func flushPendingStateUpdates() {
        pendingFlushTask = nil
        flushPendingStateUpdatesNow()
    }

    private func flushPendingStateUpdatesNow() {
        guard !pendingStateUpdates.isEmpty else { return }
        let updates = pendingStateUpdates.values
        pendingStateUpdates.removeAll(keepingCapacity: true)

        for (task, state) in updates {
            applyStateUpdateNow(task: task, state: state)
        }
    }

    private func applyStateUpdateNow(task: MediaDownloadTask, state: DownloadItemState) {
        let taskID = task.id
        let oldState = itemStates[taskID] ?? .queued
        guard oldState != state else { return }

        itemStates[taskID] = state
        applyProgressTransition(from: oldState, to: state)
        applyQueueTransition(taskID: taskID, from: oldState, to: state)
    }

    private func applyProgressTransition(from oldState: DownloadItemState, to newState: DownloadItemState) {
        if !oldState.isTerminal, newState.isTerminal {
            progressCompleted += 1
        } else if oldState.isTerminal, !newState.isTerminal {
            progressCompleted = max(0, progressCompleted - 1)
        }
    }

    private func applyQueueTransition(taskID: String, from oldState: DownloadItemState, to newState: DownloadItemState) {
        let oldBucket = bucket(for: oldState)
        let newBucket = bucket(for: newState)

        if oldBucket == .queued, newBucket != .queued {
            queuedTaskCount = max(0, queuedTaskCount - 1)
        } else if oldBucket != .queued, newBucket == .queued {
            queuedTaskCount += 1
        }

        if oldBucket == .inFlight, newBucket != .inFlight {
            removeInFlight(taskID)
        } else if oldBucket != .inFlight, newBucket == .inFlight {
            addInFlight(taskID)
        }

        if oldBucket == .finished, newBucket != .finished {
            removeFinished(taskID)
        } else if oldBucket != .finished, newBucket == .finished {
            addFinished(taskID)
        }
    }

    private func addInFlight(_ taskID: String) {
        guard inFlightTaskIDSet.insert(taskID).inserted else { return }
        inFlightTaskIDs.append(taskID)
    }

    private func removeInFlight(_ taskID: String) {
        guard inFlightTaskIDSet.remove(taskID) != nil else { return }
        inFlightTaskIDs.removeAll { $0 == taskID }
    }

    private func addFinished(_ taskID: String) {
        guard finishedTaskIDSet.insert(taskID).inserted else { return }
        finishedTaskIDs.append(taskID)
    }

    private func removeFinished(_ taskID: String) {
        guard finishedTaskIDSet.remove(taskID) != nil else { return }
        finishedTaskIDs.removeAll { $0 == taskID }
    }

    private func normalizeScreenName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }
}
