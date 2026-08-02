import Foundation
import XGraphQLkit
import OSLog
import WebKit

final class AuthService {
    private static let logger = Logger(subsystem: "jp.yyyywaiwai.BirdSaver", category: "AuthStore")
    private let keychain: KeychainStore
    private let account = "x-auth-context"

    init(keychain: KeychainStore = KeychainStore(service: "jp.yyyywaiwai.BirdSaver")) {
        self.keychain = keychain
    }

    func loadAuthContext() throws -> XAuthContext? {
        guard let data = try keychain.load(account: account) else {
            return nil
        }

        let snapshot = try JSONDecoder().decode(AuthSnapshot.self, from: data)
        return snapshot.authContext
    }

    func saveAuthContext(_ context: XAuthContext) throws {
        let snapshot = AuthSnapshot(context: context)
        let data = try JSONEncoder().encode(snapshot)
        do {
            try keychain.save(data, account: account)
            Self.logger.notice("X authentication context saved to Keychain")
        } catch {
            Self.logger.error("Keychain save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func clearAuthContext() async throws {
        try keychain.delete(account: account)
        await clearWebsiteData()
        Self.logger.notice("X authentication context and website data cleared")
    }

    private func clearWebsiteData() async {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        await withCheckedContinuation { continuation in
            dataStore.removeData(
                ofTypes: dataTypes,
                modifiedSince: .distantPast,
                completionHandler: continuation.resume
            )
        }
    }
}
