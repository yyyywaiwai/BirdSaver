import Foundation

struct DownloadMetrics: Equatable {
    let queued: Int
    let processing: Int
    let succeeded: Int
    let skipped: Int
    let failed: Int

    init(states: [String: DownloadItemState]) {
        var queued = 0
        var processing = 0
        var succeeded = 0
        var skipped = 0
        var failed = 0

        for state in states.values {
            switch state {
            case .queued:
                queued += 1
            case .downloading, .converting:
                processing += 1
            case .succeeded:
                succeeded += 1
            case .skipped:
                skipped += 1
            case .failed:
                failed += 1
            }
        }

        self.queued = queued
        self.processing = processing
        self.succeeded = succeeded
        self.skipped = skipped
        self.failed = failed
    }

    var completed: Int {
        succeeded + skipped + failed
    }

    var remaining: Int {
        queued + processing
    }

    var total: Int {
        completed + remaining
    }
}
