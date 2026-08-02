import SwiftUI

struct DownloadActivityView: View {
    @ObservedObject var viewModel: BirdSaverViewModel

    @State private var filter: ActivityFilter = .all
    @State private var searchText = ""
    @State private var selectedTaskID: String?

    var body: some View {
        let tasks = visibleTasks
        let taskTable = DownloadTaskTable(
            tasks: tasks,
            states: viewModel.itemStates,
            selection: $selectedTaskID
        )
        .frame(minHeight: BirdSaverDesign.activityTableMinimumHeight)

        VStack(spacing: 0) {
            DownloadActivityHeader(viewModel: viewModel)

            Divider()

            HStack(spacing: BirdSaverDesign.sectionSpacing) {
                Picker("表示", selection: $filter) {
                    ForEach(ActivityFilter.allCases) { activityFilter in
                        Text(activityFilter.title).tag(activityFilter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)

                Spacer()

                Text("\(tasks.count) / \(viewModel.downloadTasks.count) 件")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, BirdSaverDesign.contentPadding)
            .padding(.vertical, 12)

            if viewModel.downloadTasks.isEmpty {
                DownloadEmptyStateView(viewModel: viewModel)
            } else if tasks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("条件に一致する項目がありません")
                        .font(.headline)
                    Text("表示フィルタまたは検索語を変更してください。")
                        .foregroundStyle(.secondary)
                    Button("フィルタをリセット") {
                        filter = .all
                        searchText = ""
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if let selectedTaskID,
                   tasks.contains(where: { $0.id == selectedTaskID }),
                   let task = viewModel.task(for: selectedTaskID) {
                    VSplitView {
                        taskTable

                        DownloadTaskDetailView(
                            task: task,
                            state: viewModel.state(forTaskID: selectedTaskID)
                        )
                        .frame(
                            minHeight: BirdSaverDesign.detailPaneMinimumHeight,
                            idealHeight: BirdSaverDesign.detailPaneIdealHeight
                        )
                    }
                    .accessibilityIdentifier("download-activity-split-view")
                } else {
                    taskTable
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("アクティビティ")
        .searchable(text: $searchText, prompt: "本文・ユーザーID・投稿ID・ファイル名・URLを検索")
    }

    private var visibleTasks: [MediaDownloadTask] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if filter == .all, query.isEmpty {
            return viewModel.downloadTasks
        }

        return viewModel.downloadTasks.filter { task in
            let state = viewModel.state(forTaskID: task.id)
            guard filter.includes(state) else {
                return false
            }

            guard !query.isEmpty else {
                return true
            }

            return task.id.localizedStandardContains(query)
                || task.postID.localizedStandardContains(query)
                || task.mediaID.localizedStandardContains(query)
                || task.postText.localizedStandardContains(query)
                || task.authorScreenName.localizedStandardContains(query)
                || (task.authorUserID?.localizedStandardContains(query) ?? false)
                || task.postURL.absoluteString.localizedStandardContains(query)
                || task.targetPath.lastPathComponent.localizedStandardContains(query)
                || task.sourceURL.absoluteString.localizedStandardContains(query)
        }
    }
}
