//
//  CodexDashboardManager.swift
//  boringNotch
//

import AppKit
import Combine
import Foundation

@MainActor
final class CodexDashboardManager: ObservableObject {
    static let shared = CodexDashboardManager()

    @Published private(set) var dashboard: CodexDashboard?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private init() {}

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let data = try await XPCHelperClient.shared.fetchCodexDashboard()
            dashboard = try JSONDecoder().decode(CodexDashboard.self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func openCodex() {
        open(URL(string: "codex://launch"))
    }

    func openSession(_ session: CodexSession) {
        let encodedID = session.id.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? session.id
        open(URL(string: "codex://threads/\(encodedID)"))
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }
}
