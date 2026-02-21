import Foundation

final class AppSettingsStore {
    private enum Keys {
        static let screenName = "settings.screen_name"
        static let maxPosts = "settings.max_posts"
        static let lastRunAt = "settings.last_run_at"
        static let includePhotos = "settings.include_photos"
        static let includeVideos = "settings.include_videos"
        static let maxConcurrentDownloads = "settings.max_concurrent_downloads"
        static let baseDirectoryPath = "settings.base_directory_path"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var screenName: String {
        get { defaults.string(forKey: Keys.screenName) ?? "" }
        set { defaults.set(newValue, forKey: Keys.screenName) }
    }

    var maxPosts: Int {
        get {
            let value = defaults.integer(forKey: Keys.maxPosts)
            if value == 0 {
                return DownloadConfig.maxPostLimit
            }
            return max(1, min(value, DownloadConfig.maxPostLimit))
        }
        set {
            defaults.set(max(1, min(newValue, DownloadConfig.maxPostLimit)), forKey: Keys.maxPosts)
        }
    }

    var includePhotos: Bool {
        get {
            if defaults.object(forKey: Keys.includePhotos) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.includePhotos)
        }
        set { defaults.set(newValue, forKey: Keys.includePhotos) }
    }

    var includeVideos: Bool {
        get {
            if defaults.object(forKey: Keys.includeVideos) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.includeVideos)
        }
        set { defaults.set(newValue, forKey: Keys.includeVideos) }
    }

    var maxConcurrentDownloads: Int {
        get {
            let value = defaults.integer(forKey: Keys.maxConcurrentDownloads)
            if value == 0 {
                return 3
            }
            return max(1, min(value, 8))
        }
        set {
            defaults.set(max(1, min(newValue, 8)), forKey: Keys.maxConcurrentDownloads)
        }
    }

    var baseDirectoryURL: URL {
        get {
            guard let path = defaults.string(forKey: Keys.baseDirectoryPath), !path.isEmpty else {
                return DownloadConfig.defaultBaseDirectory()
            }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        set {
            defaults.set(newValue.standardizedFileURL.path, forKey: Keys.baseDirectoryPath)
        }
    }

    var lastRunAt: Date? {
        get { defaults.object(forKey: Keys.lastRunAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastRunAt) }
    }
}
