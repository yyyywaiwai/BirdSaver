import Foundation

final class AppSettingsStore {
    private enum Keys {
        static let screenName = "settings.screen_name"
        static let maxPosts = "settings.max_posts"
        static let lastRunAt = "settings.last_run_at"
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

    var lastRunAt: Date? {
        get { defaults.object(forKey: Keys.lastRunAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastRunAt) }
    }
}
