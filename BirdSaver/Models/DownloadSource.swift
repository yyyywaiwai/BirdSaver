import Foundation

enum DownloadSource: String, CaseIterable, Identifiable {
    case userMedia
    case bookmarks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .userMedia:
            "ユーザーメディア"
        case .bookmarks:
            "ブックマーク"
        }
    }
}
