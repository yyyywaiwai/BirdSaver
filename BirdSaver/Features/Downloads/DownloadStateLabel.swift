import SwiftUI

struct DownloadStateLabel: View {
    let state: DownloadItemState

    var body: some View {
        let presentation = presentation

        Label(presentation.title, systemImage: presentation.symbol)
            .foregroundStyle(presentation.color)
            .lineLimit(1)
            .accessibilityLabel("状態: \(presentation.title)")
    }

    private var presentation: (title: String, symbol: String, color: Color) {
        switch state {
        case .queued:
            return ("待機中", "clock", .secondary)
        case .downloading:
            return ("取得中", "arrow.down.circle", .blue)
        case .converting:
            return ("変換中", "gearshape.2", .orange)
        case .succeeded:
            return ("保存済み", "checkmark.circle.fill", .green)
        case .skipped:
            return ("スキップ", "forward.circle.fill", .mint)
        case .failed:
            return ("失敗", "xmark.circle.fill", .red)
        }
    }
}
