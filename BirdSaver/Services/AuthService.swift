import Foundation
import XGraphQLkit

final class AuthService {
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
        try keychain.save(data, account: account)
    }

    func clearAuthContext() throws {
        try keychain.delete(account: account)
    }
}
