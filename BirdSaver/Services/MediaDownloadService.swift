import Foundation
import AVFoundation

actor MediaDownloadService {
    typealias StateUpdate = @Sendable (MediaDownloadTask, DownloadItemState) async -> Void

    private let session: URLSession
    private let fileManager: FileManager

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    func downloadAll(
        tasks: [MediaDownloadTask],
        concurrency: Int,
        onUpdate: @escaping StateUpdate
    ) async -> DownloadSummary {
        guard !tasks.isEmpty else {
            return .empty
        }

        var succeeded = 0
        var skipped = 0
        var failed = 0
        var failures: [DownloadFailure] = []

        for task in tasks {
            await onUpdate(task, .queued)
        }

        let maxConcurrent = max(1, concurrency)
        var index = 0

        while index < tasks.count {
            if Task.isCancelled {
                break
            }

            let batchEnd = min(index + maxConcurrent, tasks.count)
            let batch = Array(tasks[index..<batchEnd])

            await withTaskGroup(of: (MediaDownloadTask, DownloadItemState).self) { group in
                for task in batch {
                    group.addTask {
                        let state = await self.processTask(task, onUpdate: onUpdate)
                        return (task, state)
                    }
                }

                for await (task, finalState) in group {
                    switch finalState {
                    case .succeeded:
                        succeeded += 1
                    case .skipped:
                        skipped += 1
                    case .failed(let message):
                        failed += 1
                        failures.append(
                            DownloadFailure(
                                id: UUID().uuidString,
                                taskID: task.id,
                                reason: message
                            )
                        )
                    case .queued, .downloading, .converting:
                        break
                    }
                }
            }

            index = batchEnd
        }

        return DownloadSummary(
            total: tasks.count,
            succeeded: succeeded,
            skipped: skipped,
            failed: failed,
            failures: failures
        )
    }

    private func processTask(
        _ task: MediaDownloadTask,
        onUpdate: @escaping StateUpdate
    ) async -> DownloadItemState {
        do {
            try Task.checkCancellation()

            if fileManager.fileExists(atPath: task.targetPath.path) {
                let state = DownloadItemState.skipped(task.targetPath)
                await onUpdate(task, state)
                return state
            }

            try createParentDirectoryIfNeeded(for: task.targetPath)

            await onUpdate(task, .downloading)

            switch task.kind {
            case .photo:
                try await downloadFile(from: task.sourceURL, to: task.targetPath)
                let state = DownloadItemState.succeeded(task.targetPath)
                await onUpdate(task, state)
                return state

            case .video, .animatedGif:
                let kind = videoTransportKind(for: task.sourceURL)
                switch kind {
                case .mp4:
                    try await downloadFile(from: task.sourceURL, to: task.targetPath)
                    let state = DownloadItemState.succeeded(task.targetPath)
                    await onUpdate(task, state)
                    return state

                case .m3u8:
                    await onUpdate(task, .converting)
                    try await convertM3U8ToMP4(source: task.sourceURL, destination: task.targetPath)
                    let state = DownloadItemState.succeeded(task.targetPath)
                    await onUpdate(task, state)
                    return state

                case .unknown:
                    throw NSError(domain: "MediaDownload", code: 30, userInfo: [NSLocalizedDescriptionKey: "Unsupported video URL format"])
                }
            }
        } catch is CancellationError {
            let state = DownloadItemState.failed("Cancelled")
            await onUpdate(task, state)
            return state
        } catch {
            let state = DownloadItemState.failed(error.localizedDescription)
            await onUpdate(task, state)
            return state
        }
    }

    private func createParentDirectoryIfNeeded(for fileURL: URL) throws {
        let parent = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: parent.path) {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        }
    }

    private func downloadFile(from source: URL, to destination: URL) async throws {
        let (tempURL, response) = try await session.download(from: source)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            throw NSError(domain: "MediaDownload", code: 10, userInfo: [NSLocalizedDescriptionKey: "Download failed: \(source.absoluteString)"])
        }

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.moveItem(at: tempURL, to: destination)
    }

    private enum VideoTransportKind {
        case mp4
        case m3u8
        case unknown
    }

    private func videoTransportKind(for url: URL) -> VideoTransportKind {
        let absolute = url.absoluteString.lowercased()
        if absolute.contains(".m3u8") {
            return .m3u8
        }
        if absolute.contains(".mp4") || url.pathExtension.lowercased() == "mp4" {
            return .mp4
        }
        return .unknown
    }

    private func convertM3U8ToMP4(source: URL, destination: URL) async throws {
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        let asset = AVURLAsset(url: source)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
            ?? AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        else {
            throw NSError(
                domain: "MediaDownload",
                code: 31,
                userInfo: [NSLocalizedDescriptionKey: "HLS export session could not be created"]
            )
        }

        let compatibleFileTypes = try await compatibleFileTypes(for: exportSession)
        guard compatibleFileTypes.contains(.mp4) else {
            throw NSError(
                domain: "MediaDownload",
                code: 32,
                userInfo: [NSLocalizedDescriptionKey: "This stream is not exportable as MP4 by AVFoundation"]
            )
        }

        exportSession.outputURL = destination
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        try await export(using: exportSession)
    }

    private func compatibleFileTypes(for session: AVAssetExportSession) async throws -> [AVFileType] {
        await withCheckedContinuation { continuation in
            session.determineCompatibleFileTypes { fileTypes in
                continuation.resume(returning: fileTypes)
            }
        }
    }

    private func export(using session: AVAssetExportSession) async throws {
        try await withCheckedThrowingContinuation { continuation in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .failed:
                    continuation.resume(
                        throwing: session.error ?? NSError(
                            domain: "MediaDownload",
                            code: 33,
                            userInfo: [NSLocalizedDescriptionKey: "AVFoundation export failed"]
                        )
                    )
                default:
                    continuation.resume(
                        throwing: NSError(
                            domain: "MediaDownload",
                            code: 34,
                            userInfo: [NSLocalizedDescriptionKey: "AVFoundation export ended in unexpected state"]
                        )
                    )
                }
            }
        }
    }
}
