import Foundation
import XGraphQLkit

actor TimelineService {
    func collectBookmarkMediaTasks(
        config: DownloadConfig,
        auth: XAuthContext,
        onProgress: (@Sendable (TimelineFetchProgress) async -> Void)? = nil
    ) async throws -> TimelineMediaResult {
        let client = XDirectClient(auth: auth)
        var cursor: String?
        var seenCursors = Set<String>()
        var scannedPosts = 0
        var tasks: [MediaDownloadTask] = []
        var seenURLs = Set<String>()

        await emitProgress(
            scannedPosts: scannedPosts,
            collectedTasks: tasks.count,
            onProgress: onProgress
        )

        while scannedPosts < config.clampedMaxPosts {
            try Task.checkCancellation()

            let page = try await client.listBookmarks(
                count: 100,
                cursor: cursor
            )

            if page.posts.isEmpty {
                break
            }

            appendTasks(
                from: page.posts,
                config: config,
                scannedPosts: &scannedPosts,
                tasks: &tasks,
                seenURLs: &seenURLs
            )

            await emitProgress(
                scannedPosts: scannedPosts,
                collectedTasks: tasks.count,
                onProgress: onProgress
            )

            guard let nextCursor = page.nextCursor,
                  seenCursors.insert(nextCursor).inserted else {
                break
            }
            cursor = nextCursor
        }

        return TimelineMediaResult(
            tasks: tasks,
            scannedPosts: scannedPosts,
            reachedPostLimit: scannedPosts >= config.clampedMaxPosts
        )
    }

    func collectMediaTasks(
        config: DownloadConfig,
        auth: XAuthContext,
        onProgress: (@Sendable (TimelineFetchProgress) async -> Void)? = nil
    ) async throws -> TimelineMediaResult {
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

        await emitProgress(
            scannedPosts: scannedPosts,
            collectedTasks: tasks.count,
            onProgress: onProgress
        )

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
                    guard let task = makeTask(from: media, post: post, config: config) else {
                        continue
                    }

                    let dedupeKey = "\(task.kind.rawValue)|\(task.sourceURL.absoluteString)"
                    if seenURLs.insert(dedupeKey).inserted {
                        tasks.append(task)
                    }
                }
            }

            await emitProgress(
                scannedPosts: scannedPosts,
                collectedTasks: tasks.count,
                onProgress: onProgress
            )

            cursor = page.nextCursor
            if cursor == nil {
                break
            }
        }

        await emitProgress(
            scannedPosts: scannedPosts,
            collectedTasks: tasks.count,
            onProgress: onProgress
        )

        return TimelineMediaResult(
            tasks: tasks,
            scannedPosts: scannedPosts,
            reachedPostLimit: scannedPosts >= config.clampedMaxPosts
        )
    }

    func collectMediaTasks(
        from postURL: URL,
        config: DownloadConfig,
        auth: XAuthContext,
        onProgress: (@Sendable (TimelineFetchProgress) async -> Void)? = nil
    ) async throws -> TimelineMediaResult {
        let client = XDirectClient(auth: auth)

        await emitProgress(
            scannedPosts: 0,
            collectedTasks: 0,
            onProgress: onProgress
        )

        let post = try await client.fetchPost(from: postURL)
        var tasks: [MediaDownloadTask] = []
        var seenURLs = Set<String>()

        for media in post.media {
            guard let task = makeTask(from: media, post: post, config: config) else {
                continue
            }

            let dedupeKey = "\(task.kind.rawValue)|\(task.sourceURL.absoluteString)"
            if seenURLs.insert(dedupeKey).inserted {
                tasks.append(task)
            }
        }

        await emitProgress(
            scannedPosts: 1,
            collectedTasks: tasks.count,
            onProgress: onProgress
        )

        return TimelineMediaResult(
            tasks: tasks,
            scannedPosts: 1,
            reachedPostLimit: false
        )
    }

    private func emitProgress(
        scannedPosts: Int,
        collectedTasks: Int,
        onProgress: (@Sendable (TimelineFetchProgress) async -> Void)?
    ) async {
        guard let onProgress else { return }
        await onProgress(
            TimelineFetchProgress(
                scannedPosts: scannedPosts,
                collectedTasks: collectedTasks
            )
        )
    }

    private func appendTasks(
        from posts: [XPost],
        config: DownloadConfig,
        scannedPosts: inout Int,
        tasks: inout [MediaDownloadTask],
        seenURLs: inout Set<String>
    ) {
        for post in posts {
            if scannedPosts >= config.clampedMaxPosts {
                break
            }

            scannedPosts += 1
            for media in post.media {
                guard let task = makeTask(from: media, post: post, config: config) else {
                    continue
                }

                let dedupeKey = "\(task.kind.rawValue)|\(task.sourceURL.absoluteString)"
                if seenURLs.insert(dedupeKey).inserted {
                    tasks.append(task)
                }
            }
        }
    }

    private func makeTask(from media: XMediaItem, post: XPost, config: DownloadConfig) -> MediaDownloadTask? {
        let kind = MediaDownloadKind(mediaKind: media.kind)
        let safeMediaID = sanitize(media.id)
        let baseFileName = "\(post.id)_\(safeMediaID)"

        switch kind {
        case .photo:
            guard config.includePhotos else {
                return nil
            }
            let preferredURL = preferredPhotoURL(from: media.url)
            let ext = fileExtension(from: preferredURL, fallback: "jpg")
            let targetURL = config.photosDirectory.appendingPathComponent("\(baseFileName).\(ext)")
            return MediaDownloadTask(
                postID: post.id,
                postText: post.text,
                authorScreenName: post.screenName,
                postURL: post.url,
                mediaID: safeMediaID,
                sourceURL: preferredURL,
                kind: kind,
                targetPath: targetURL
            )

        case .video, .animatedGif:
            // XGraphQLkit の XSearchTimelineType.videos と同様に
            // video + animatedGif を動画カテゴリとして扱う。
            guard config.includeVideos else {
                return nil
            }
            let targetURL = config.videosDirectory.appendingPathComponent("\(baseFileName).mp4")
            return MediaDownloadTask(
                postID: post.id,
                postText: post.text,
                authorScreenName: post.screenName,
                postURL: post.url,
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
            if let format = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name.lowercased() == "format" })?
                .value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !format.isEmpty {
                return format.lowercased()
            }
            return fallback
        }
        return ext.lowercased()
    }

    private func preferredPhotoURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(),
              host.hasSuffix("pbs.twimg.com") else {
            return url
        }

        var items = components.queryItems ?? []
        let hasFormat = items.contains { $0.name.lowercased() == "format" && !($0.value ?? "").isEmpty }
        if !hasFormat {
            let ext = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !ext.isEmpty {
                items.append(URLQueryItem(name: "format", value: ext))
            }
        }

        items.removeAll { $0.name.lowercased() == "name" }
        items.append(URLQueryItem(name: "name", value: "orig"))
        components.queryItems = items

        return components.url ?? url
    }
}
