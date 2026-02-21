import Foundation
import XGraphQLkit

struct AuthSnapshot: Codable {
    let cookieHeader: String
    let csrfToken: String
    let bearerToken: String
    let language: String
    let clientTransactionID: String?
    let clientTransactionIDsByOperation: [String: String]
    let operationIDOverrides: [String: String]

    init(context: XAuthContext) {
        cookieHeader = context.cookieHeader
        csrfToken = context.csrfToken
        bearerToken = context.bearerToken
        language = context.language
        clientTransactionID = context.clientTransactionID
        clientTransactionIDsByOperation = context.clientTransactionIDsByOperation
        operationIDOverrides = context.operationIDOverrides
    }

    var authContext: XAuthContext {
        XAuthContext(
            cookieHeader: cookieHeader,
            csrfToken: csrfToken,
            bearerToken: bearerToken,
            language: language,
            clientTransactionID: clientTransactionID,
            clientTransactionIDsByOperation: clientTransactionIDsByOperation,
            operationIDOverrides: operationIDOverrides
        )
    }
}

struct DownloadConfig: Equatable {
    nonisolated static let maxPostLimit = 1000

    let screenName: String
    let maxPosts: Int
    let includeOwnPostsOnly: Bool
    let includePhotos: Bool
    let includeVideos: Bool
    let baseDirectory: URL

    nonisolated var normalizedScreenName: String {
        let trimmed = screenName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("@") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    nonisolated var userDirectory: URL {
        baseDirectory.appendingPathComponent(normalizedScreenName, isDirectory: true)
    }

    nonisolated var photosDirectory: URL {
        userDirectory.appendingPathComponent("photos", isDirectory: true)
    }

    nonisolated var videosDirectory: URL {
        userDirectory.appendingPathComponent("videos", isDirectory: true)
    }

    nonisolated var clampedMaxPosts: Int {
        max(1, min(maxPosts, Self.maxPostLimit))
    }

    nonisolated static func defaultBaseDirectory() -> URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
            .appendingPathComponent("BirdSaver", isDirectory: true)
    }
}

enum MediaDownloadKind: String, Codable, Hashable {
    case photo
    case video
    case animatedGif

    nonisolated init(mediaKind: XMediaKind) {
        switch mediaKind {
        case .photo:
            self = .photo
        case .video:
            self = .video
        case .animatedGif:
            self = .animatedGif
        }
    }
}

struct MediaDownloadTask: Identifiable, Hashable {
    let postID: String
    let mediaID: String
    let sourceURL: URL
    let kind: MediaDownloadKind
    let targetPath: URL

    nonisolated var id: String {
        "\(postID)-\(mediaID)"
    }
}

enum DownloadItemState: Equatable {
    case queued
    case downloading
    case converting
    case succeeded(URL)
    case skipped(URL)
    case failed(String)

    var isTerminal: Bool {
        switch self {
        case .succeeded, .skipped, .failed:
            return true
        case .queued, .downloading, .converting:
            return false
        }
    }
}

struct DownloadFailure: Identifiable, Equatable {
    let id: String
    let taskID: String
    let reason: String
}

struct DownloadSummary: Equatable {
    let total: Int
    let succeeded: Int
    let skipped: Int
    let failed: Int
    let failures: [DownloadFailure]

    nonisolated static let empty = DownloadSummary(total: 0, succeeded: 0, skipped: 0, failed: 0, failures: [])
}

struct TimelineMediaResult {
    let tasks: [MediaDownloadTask]
    let scannedPosts: Int
    let reachedPostLimit: Bool
}

struct TimelineFetchProgress: Sendable, Equatable {
    let scannedPosts: Int
    let collectedTasks: Int
}
