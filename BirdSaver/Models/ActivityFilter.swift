import Foundation

enum ActivityFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case completed
    case failed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "すべて"
        case .active:
            return "処理中"
        case .completed:
            return "完了"
        case .failed:
            return "失敗"
        }
    }

    func includes(_ state: DownloadItemState) -> Bool {
        switch self {
        case .all:
            return true
        case .active:
            switch state {
            case .queued, .downloading, .converting:
                return true
            case .succeeded, .skipped, .failed:
                return false
            }
        case .completed:
            switch state {
            case .succeeded, .skipped:
                return true
            case .queued, .downloading, .converting, .failed:
                return false
            }
        case .failed:
            if case .failed = state {
                return true
            }
            return false
        }
    }
}
