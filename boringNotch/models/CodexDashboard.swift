//
//  CodexDashboard.swift
//  boringNotch
//

import Foundation

struct CodexDashboard: Decodable {
    let rateLimit: CodexRateLimit?
    let usageSummary: CodexUsageSummary?
    let dailyUsage: [CodexDailyUsage]
    let sessions: [CodexSession]
    let fetchedAt: TimeInterval

    var todayTokens: Int64 {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let bucket = dailyUsage.first(where: {
            guard let date = $0.date else { return false }
            return calendar.isDate(date, inSameDayAs: today)
        }) {
            return bucket.tokens
        }

        return dailyUsage.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
            .last?.tokens ?? 0
    }

    var recentDailyUsage: [CodexDailyUsage] {
        Array(
            dailyUsage
                .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
                .suffix(7)
        )
    }
}

struct CodexRateLimit: Decodable {
    let usedPercent: Int
    let resetsAt: Int64?
    let windowDurationMins: Int64?

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }

    var windowLabel: String {
        guard let minutes = windowDurationMins else { return "额度" }
        if minutes >= 1_440, minutes.isMultiple(of: 1_440) {
            return "\(minutes / 1_440)天"
        }
        if minutes >= 60, minutes.isMultiple(of: 60) {
            return "\(minutes / 60)小时"
        }
        return "\(minutes)分钟"
    }

    var resetDate: Date? {
        resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    var resetCountdownLabel: String? {
        guard let resetDate else { return nil }
        let remaining = max(0, Int(resetDate.timeIntervalSinceNow))
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600

        if days > 0 && hours > 0 { return "\(days)天\(hours)小时" }
        if days > 0 { return "\(days)天" }
        if hours > 0 { return "\(hours)小时" }
        return "1小时内"
    }
}

struct CodexUsageSummary: Decodable {
    let lifetimeTokens: Int64?
    let peakDailyTokens: Int64?
    let currentStreakDays: Int64?
    let longestStreakDays: Int64?
    let longestRunningTurnSec: Int64?
}

struct CodexDailyUsage: Decodable, Identifiable {
    let startDate: String
    let tokens: Int64

    var id: String { startDate }

    var date: Date? {
        Self.dateFormatter.date(from: startDate)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct CodexSession: Decodable, Identifiable {
    let id: String
    let title: String
    let updatedAt: TimeInterval

    var updatedDate: Date {
        Date(timeIntervalSince1970: updatedAt)
    }
}
