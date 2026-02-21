import Foundation
import XGraphQLkit

actor TimelineService {
    func collectMediaTasks(config: DownloadConfig, auth: XAuthContext) async throws -> TimelineMediaResult {
        let normalizedScreenName = config.normalizedScreenName
        let targetScreenName = normalizedScreenName.lowercased()

        guard !normalizedScreenName.isEmpty else {
            return TimelineMediaResult(tasks: [], scannedPosts: 0, reachedPostLimit: false)
        }

        let client = XDirectClient(auth: auth)
        var cursor: String?
        var scannedPosts = 0
        var tasks: [MediaDownloadTask] = []
        var seenURLs = Set<String>()

        while scannedPosts < config.clampedMaxPosts {
            try Task.checkCancellation()

            let page = try await client.listUserPosts(
                screenName: normalizedScreenName,
                timeline: .media,
                count: 100,
                cursor: cursor
            )

            if page.posts.isEmpty {
                break
            }

            for post in page.posts {
                if scannedPosts >= config.clampedMaxPosts {
                    break
                }

                scannedPosts += 1

                if config.includeOwnPostsOnly,
                   post.screenName.lowercased() != targetScreenName {
                    continue
                }

                for media in post.media {
                    guard let task = makeTask(from: media, postID: post.id, config: config) else {
                        continue
                    }

                    let dedupeKey = "\(task.kind.rawValue)|\(task.sourceURL.absoluteString)"
                    if seenURLs.insert(dedupeKey).inserted {
                        tasks.append(task)
                    }
                }
            }

            cursor = page.nextCursor
            if cursor == nil {
                break
            }
        }

        return TimelineMediaResult(
            tasks: tasks,
            scannedPosts: scannedPosts,
            reachedPostLimit: scannedPosts >= config.clampedMaxPosts
        )
    }

    private func makeTask(from media: XMediaItem, postID: String, config: DownloadConfig) -> MediaDownloadTask? {
        let kind = MediaDownloadKind(mediaKind: media.kind)
        let safeMediaID = sanitize(media.id)
        let baseFileName = "\(postID)_\(safeMediaID)"

        switch kind {
        case .photo:
            let ext = fileExtension(from: media.url, fallback: "jpg")
            let targetURL = config.photosDirectory.appendingPathComponent("\(baseFileName).\(ext)")
            return MediaDownloadTask(
                postID: postID,
                mediaID: safeMediaID,
                sourceURL: media.url,
                kind: kind,
                targetPath: targetURL
            )

        case .video, .animatedGif:
            let targetURL = config.videosDirectory.appendingPathComponent("\(baseFileName).mp4")
            return MediaDownloadTask(
                postID: postID,
                mediaID: safeMediaID,
                sourceURL: media.url,
                kind: kind,
                targetPath: targetURL
            )
        }
    }

    private func sanitize(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "\\/:*?\"<>| ")
        return value.components(separatedBy: invalid).joined(separator: "_")
    }

    private func fileExtension(from url: URL, fallback: String) -> String {
        let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        if ext.isEmpty {
            return fallback
        }
        return ext.lowercased()
    }
}
