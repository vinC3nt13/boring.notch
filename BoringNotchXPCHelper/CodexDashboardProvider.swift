//
//  CodexDashboardProvider.swift
//  BoringNotchXPCHelper
//

import Foundation

enum CodexDashboardProvider {
    private static let executableCandidates = [
        "/Applications/ChatGPT.app/Contents/Resources/codex",
        "/Applications/Codex.app/Contents/Resources/codex"
    ]

    static func fetch(completion: @escaping (Data?, String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = try readAppServer()
                let snapshot = makeSnapshot(from: results)
                let data = try JSONSerialization.data(withJSONObject: snapshot)
                completion(data, nil)
            } catch {
                completion(nil, error.localizedDescription)
            }
        }
    }

    private static func readAppServer() throws -> [Int: Any] {
        guard let executable = executableCandidates.first(
            where: FileManager.default.isExecutableFile(atPath:)
        ) else {
            throw ProviderError.codexNotInstalled
        }

        let process = Process()
        let standardInput = Pipe()
        let standardOutput = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server"]
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = FileHandle.nullDevice

        let lock = NSLock()
        let completed = DispatchSemaphore(value: 0)
        var buffer = Data()
        var results: [Int: Any] = [:]

        standardOutput.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            lock.lock()
            buffer.append(data)

            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer.prefix(upTo: newline)
                buffer.removeSubrange(...newline)

                guard
                    let object = try? JSONSerialization.jsonObject(with: Data(line)),
                    let message = object as? [String: Any],
                    let id = message["id"] as? Int,
                    let result = message["result"]
                else { continue }

                results[id] = result
            }

            let hasAllResponses = results[2] != nil && results[3] != nil && results[4] != nil
            lock.unlock()

            if hasAllResponses {
                completed.signal()
            }
        }

        do {
            try process.run()
        } catch {
            standardOutput.fileHandleForReading.readabilityHandler = nil
            throw ProviderError.couldNotLaunch
        }

        let messages: [[String: Any]] = [
            [
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "boring-notch",
                        "version": "1.0"
                    ]
                ]
            ],
            ["method": "initialized"],
            ["id": 2, "method": "account/rateLimits/read", "params": [:]],
            ["id": 3, "method": "account/usage/read", "params": [:]],
            [
                "id": 4,
                "method": "thread/list",
                "params": [
                    "limit": 3,
                    "archived": false,
                    "sortKey": "recency_at",
                    "sortDirection": "desc",
                    "useStateDbOnly": true
                ]
            ]
        ]

        for message in messages {
            let data = try JSONSerialization.data(withJSONObject: message)
            standardInput.fileHandleForWriting.write(data)
            standardInput.fileHandleForWriting.write(Data([0x0A]))
        }

        let waitResult = completed.wait(timeout: .now() + 10)
        standardOutput.fileHandleForReading.readabilityHandler = nil
        try? standardInput.fileHandleForWriting.close()

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }

        guard waitResult == .success else {
            throw ProviderError.timedOut
        }

        lock.lock()
        let finalResults = results
        lock.unlock()
        return finalResults
    }

    private static func makeSnapshot(from results: [Int: Any]) -> [String: Any] {
        let rateLimitResponse = results[2] as? [String: Any]
        let usageResponse = results[3] as? [String: Any]
        let threadResponse = results[4] as? [String: Any]

        var snapshot: [String: Any] = [
            "dailyUsage": usageResponse?["dailyUsageBuckets"] as? [[String: Any]] ?? [],
            "sessions": makeSessions(from: threadResponse),
            "fetchedAt": Date().timeIntervalSince1970
        ]

        if let summary = usageResponse?["summary"] as? [String: Any] {
            snapshot["usageSummary"] = summary
        }

        if let rateLimit = preferredRateLimit(from: rateLimitResponse) {
            snapshot["rateLimit"] = rateLimit
        }

        return snapshot
    }

    private static func preferredRateLimit(from response: [String: Any]?) -> [String: Any]? {
        guard let response else { return nil }

        var rateLimits = response["rateLimits"] as? [String: Any]
        if let byID = response["rateLimitsByLimitId"] as? [String: Any],
           let codex = byID["codex"] as? [String: Any] {
            rateLimits = codex
        }

        guard let rateLimits else { return nil }
        let windows = [
            rateLimits["primary"] as? [String: Any],
            rateLimits["secondary"] as? [String: Any]
        ].compactMap { $0 }

        let longWindows = windows.filter {
            guard let minutes = $0["windowDurationMins"] as? Int else { return true }
            return minutes >= 1_440
        }

        return longWindows.max {
            ($0["windowDurationMins"] as? Int ?? 0)
                < ($1["windowDurationMins"] as? Int ?? 0)
        }
    }

    private static func makeSessions(from response: [String: Any]?) -> [[String: Any]] {
        guard let threads = response?["data"] as? [[String: Any]] else { return [] }

        return threads.prefix(3).compactMap { thread in
            guard let id = thread["id"] as? String else { return nil }

            let name = (thread["name"] as? String)?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let preview = (thread["preview"] as? String)?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let title = [name, preview]
                .compactMap { $0 }
                .first { !$0.isEmpty } ?? "未命名会话"
            let updatedAt = (thread["recencyAt"] as? NSNumber)?.doubleValue
                ?? (thread["updatedAt"] as? NSNumber)?.doubleValue
                ?? 0

            return [
                "id": id,
                "title": title,
                "updatedAt": updatedAt
            ]
        }
    }

    private enum ProviderError: LocalizedError {
        case codexNotInstalled
        case couldNotLaunch
        case timedOut

        var errorDescription: String? {
            switch self {
            case .codexNotInstalled:
                return "未找到 Codex 应用"
            case .couldNotLaunch:
                return "无法启动 Codex 本地服务"
            case .timedOut:
                return "读取 Codex 数据超时"
            }
        }
    }
}
