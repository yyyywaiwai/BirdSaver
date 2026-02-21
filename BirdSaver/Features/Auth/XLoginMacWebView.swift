import SwiftUI
import WebKit
import XGraphQLkit

struct XLoginMacWebView: NSViewRepresentable {
    typealias NSViewType = WKWebView

    let loginURL: URL
    let language: String
    let onAuthCaptured: @Sendable (Result<XAuthContext, Error>) -> Void

    init(
        loginURL: URL = URL(string: "https://x.com/i/flow/login")!,
        language: String = "en",
        onAuthCaptured: @escaping @Sendable (Result<XAuthContext, Error>) -> Void
    ) {
        self.loginURL = loginURL
        self.language = language
        self.onAuthCaptured = onAuthCaptured
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(language: language, onAuthCaptured: onAuthCaptured)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: loginURL))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let language: String
        private let onAuthCaptured: @Sendable (Result<XAuthContext, Error>) -> Void
        private var delivered = false

        init(language: String, onAuthCaptured: @escaping @Sendable (Result<XAuthContext, Error>) -> Void) {
            self.language = language
            self.onAuthCaptured = onAuthCaptured
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                guard !delivered else { return }

                do {
                    let context = try await XAuthCapture.capture(
                        from: webView.configuration.websiteDataStore.httpCookieStore,
                        language: language
                    )
                    delivered = true
                    onAuthCaptured(.success(context))
                } catch {
                    // ct0 is not available until login completes.
                }
            }
        }
    }
}
