import AppKit
import Foundation

@MainActor
enum WorkspaceFileActions {
    static func chooseDirectory(startingAt initialDirectory: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.prompt = "選択"
        panel.message = "BirdSaverでメディアを保存するフォルダを選択してください"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = initialDirectory

        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }

    static func reveal(_ url: URL) {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue {
                NSWorkspace.shared.open(url)
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            return
        }

        NSWorkspace.shared.open(nearestExistingDirectory(to: url))
    }

    static func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    static func openSettings() {
        let selectors = ["showSettingsWindow:", "showPreferencesWindow:"]
        for selectorName in selectors {
            if NSApp.sendAction(Selector(selectorName), to: nil, from: nil) {
                return
            }
        }
    }

    private static func nearestExistingDirectory(to url: URL) -> URL {
        var candidate = url.standardizedFileURL
        var isDirectory: ObjCBool = false

        while candidate.path != "/" {
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }
}
