import SwiftUI
import WebKit
import XGraphQLkit
import OSLog

struct XLoginMacWebView: NSViewRepresentable {
    typealias NSViewType = WKWebView

    let loginURL: URL
    let language: String
    let onAuthCaptured: @MainActor @Sendable (Result<XAuthContext, Error>) -> Void

    init(
        loginURL: URL = URL(string: "https://x.com/i/flow/login")!,
        language: String = "en",
        onAuthCaptured: @escaping @MainActor @Sendable (Result<XAuthContext, Error>) -> Void
    ) {
        self.loginURL = loginURL
        self.language = language
        self.onAuthCaptured = onAuthCaptured
    }

    func makeCoordinator() -> Coordinator {
        let callback = onAuthCaptured
        return Coordinator(language: language) { result in
            callback(result)
        }
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.attach(webView: webView)
        webView.load(URLRequest(url: loginURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
        nsView.navigationDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKHTTPCookieStoreObserver {
        private static let logger = Logger(subsystem: "jp.yyyywaiwai.BirdSaver", category: "XLogin")
        private static let maximumCaptureFailureCount = 6

        private let language: String
        private let onAuthCaptured: @MainActor @Sendable (Result<XAuthContext, Error>) -> Void
        private var delivered = false
        private weak var webView: WKWebView?
        private var cookieStore: WKHTTPCookieStore?
        private var captureTask: Task<Void, Never>?
        private var pollTask: Task<Void, Never>?
        private var bearerTokenCache: String?
        private var captureFailureCount = 0

        init(
            language: String,
            onAuthCaptured: @escaping @MainActor @Sendable (Result<XAuthContext, Error>) -> Void
        ) {
            self.language = language
            self.onAuthCaptured = onAuthCaptured
        }

        func attach(webView: WKWebView) {
            self.webView = webView
            let store = webView.configuration.websiteDataStore.httpCookieStore
            cookieStore = store
            store.add(self)

            startPolling(cookieStore: store)
            scheduleCapture(cookieStore: store)
        }

        func stop() {
            delivered = true
            captureTask?.cancel()
            captureTask = nil
            pollTask?.cancel()
            pollTask = nil

            if let cookieStore {
                cookieStore.remove(self)
            }
            cookieStore = nil
            webView = nil
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            scheduleCapture(cookieStore: webView.configuration.websiteDataStore.httpCookieStore)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            scheduleCapture(cookieStore: webView.configuration.websiteDataStore.httpCookieStore)
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            scheduleCapture(cookieStore: cookieStore)
        }

        private func startPolling(cookieStore: WKHTTPCookieStore) {
            pollTask?.cancel()
            pollTask = Task { [weak self] in
                guard let self else { return }
                while !Task.isCancelled && !delivered {
                    scheduleCapture(cookieStore: cookieStore)
                    try? await Task.sleep(for: .milliseconds(900))
                }
            }
        }

        private func scheduleCapture(cookieStore: WKHTTPCookieStore) {
            guard !delivered, captureTask == nil else { return }

            captureTask = Task { [weak self] in
                guard let self else { return }
                defer { captureTask = nil }
                do {
                    guard let context = try await captureIfPossible(cookieStore: cookieStore) else {
                        return
                    }
                    guard !delivered else { return }
                    delivered = true
                    Self.logger.notice("Authenticated X cookies and public bearer captured")
                    onAuthCaptured(.success(context))
                } catch {
                    guard !Task.isCancelled, !delivered else { return }

                    captureFailureCount += 1
                    Self.logger.error("Authentication capture retry: \(error.localizedDescription, privacy: .public)")

                    guard captureFailureCount >= Self.maximumCaptureFailureCount else {
                        return
                    }

                    delivered = true
                    pollTask?.cancel()
                    pollTask = nil
                    onAuthCaptured(.failure(error))
                }
            }
        }

        private func captureIfPossible(cookieStore: WKHTTPCookieStore) async throws -> XAuthContext? {
            let cookies = await allCookies(from: cookieStore)
            guard let ct0 = cookies.first(where: { $0.name == "ct0" })?.value,
                  !ct0.isEmpty else {
                return nil
            }

            Self.logger.debug("Authenticated cookie candidates detected: \(cookies.count, privacy: .public)")

            let cookieHeader = cookies
                .sorted { $0.name < $1.name }
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")

            let bearerToken: String
            if let bearerTokenCache {
                bearerToken = bearerTokenCache
            } else {
                bearerToken = try await XAuthCapture.fetchPublicBearerToken()
                bearerTokenCache = bearerToken
                Self.logger.debug("Public bearer token resolved")
            }

            return XAuthContext(
                cookieHeader: cookieHeader,
                csrfToken: ct0,
                bearerToken: bearerToken,
                language: language
            )
        }

        private func allCookies(from cookieStore: WKHTTPCookieStore) async -> [HTTPCookie] {
            await withCheckedContinuation { continuation in
                cookieStore.getAllCookies { cookies in
                    continuation.resume(returning: cookies)
                }
            }
        }
    }
}
