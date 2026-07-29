//
//  CodexDashboardView.swift
//  boringNotch
//

import Foundation
import SwiftUI

struct CodexDashboardView: View {
    @ObservedObject private var manager = CodexDashboardManager.shared

    private let accent = Color(red: 0.48, green: 0.30, blue: 0.96)

    var body: some View {
        Group {
            if let dashboard = manager.dashboard {
                dashboardContent(dashboard)
            } else if manager.isLoading {
                ProgressView("正在读取 Codex…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                unavailableView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if manager.dashboard == nil {
                await manager.refresh()
            }
        }
    }

    private func dashboardContent(_ dashboard: CodexDashboard) -> some View {
        HStack(spacing: 12) {
            rateLimitColumn(dashboard.rateLimit)
                .frame(width: 150)

            divider

            usageColumn(dashboard)
                .frame(width: 190)

            divider

            sessionsColumn(dashboard.sessions)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func rateLimitColumn(_ rateLimit: CodexRateLimit?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Codex 用量")
                .font(.system(size: 14, weight: .semibold))

            if let rateLimit {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(.gray.opacity(0.22), lineWidth: 7)

                        Circle()
                            .trim(from: 0, to: CGFloat(rateLimit.remainingPercent) / 100)
                            .stroke(
                                accent,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text(rateLimit.windowLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(rateLimit.remainingPercent)%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("剩余")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 82, height: 82)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("已用 \(rateLimit.usedPercent)%")
                            .font(.caption)
                            .foregroundStyle(accent)
                        if let resetDate = rateLimit.resetDate {
                            Text("重置")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(resetDate, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                Text("暂无额度数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    private func usageColumn(_ dashboard: CodexDashboard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今日 Tokens")
                .font(.system(size: 14, weight: .semibold))

            Text(formatTokens(dashboard.todayTokens))
                .font(.system(size: 26, weight: .bold, design: .rounded))

            DailyUsageBars(items: dashboard.recentDailyUsage, accent: accent)
                .frame(height: 62)

            if let usedPercent = dashboard.rateLimit?.usedPercent {
                VStack(spacing: 3) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.gray.opacity(0.22))
                            Capsule()
                                .fill(accent)
                                .frame(
                                    width: geometry.size.width
                                        * CGFloat(max(0, min(100, usedPercent))) / 100
                                )
                        }
                    }
                    .frame(height: 5)

                    HStack {
                        Text("当前窗口")
                        Spacer()
                        Text("已用 \(usedPercent)%")
                            .foregroundStyle(accent)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func sessionsColumn(_ sessions: [CodexSession]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("最近会话")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button {
                    Task { await manager.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(manager.isLoading)
            }

            if sessions.isEmpty {
                Text("暂无最近会话")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                ForEach(sessions.prefix(3)) { session in
                    Button {
                        manager.openSession(session)
                    } label: {
                        HStack(spacing: 7) {
                            CodexGlyph(size: 13)
                                .foregroundStyle(.white)

                            VStack(alignment: .leading, spacing: 0) {
                                Text(session.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text(session.updatedDate, style: .relative)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 2)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                manager.openCodex()
            } label: {
                HStack(spacing: 6) {
                    CodexGlyph(size: 13)
                    Text("打开 Codex")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(.gray.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 8) {
            CodexGlyph(size: 26)
                .foregroundStyle(.white)
            Text(manager.errorMessage ?? "暂时无法读取 Codex 数据")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("重新加载") {
                Task { await manager.refresh() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.gray.opacity(0.2))
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    private func formatTokens(_ tokens: Int64) -> String {
        let value = Double(tokens)
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return "\(tokens)"
    }
}

private struct DailyUsageBars: View {
    let items: [CodexDailyUsage]
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            let maxTokens = max(items.map(\.tokens).max() ?? 0, 1)
            let spacing: CGFloat = 5
            let count = max(items.count, 1)
            let barWidth = max(
                3,
                (geometry.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            )

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(items) { item in
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(accent.opacity(0.85))
                            .frame(
                                width: barWidth,
                                height: max(
                                    4,
                                    geometry.size.height * 0.72
                                        * CGFloat(item.tokens) / CGFloat(maxTokens)
                                )
                            )

                        Text(weekday(for: item.date))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    private func weekday(for date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EE"
        return formatter.string(from: date)
    }
}
