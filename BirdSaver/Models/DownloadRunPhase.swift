import Foundation

enum DownloadRunPhase: Equatable {
    case idle
    case fetching
    case downloading
    case cancelling
    case completed
    case completedWithFailures
    case empty
    case cancelled
    case failed
}
