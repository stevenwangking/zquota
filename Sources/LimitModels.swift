import Foundation

struct LimitMeter: Equatable {
    let title: String
    let shortTitle: String
    let usedPercent: Double
    let remainingPercent: Double
    let resetDate: Date?

    var remainingText: String {
        "\(Int(remainingPercent.rounded()))%"
    }

    var resetText: String {
        guard let resetDate else {
            return "重置 --"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = .current
        formatter.dateFormat = "MM月dd日 HH:mm"

        return "\(formatter.string(from: resetDate)) 重置"
    }

    init(title: String, shortTitle: String, usedPercent: Double, resetDate: Date?) {
        self.title = title
        self.shortTitle = shortTitle
        self.usedPercent = usedPercent
        self.remainingPercent = max(0, min(100, 100 - usedPercent))
        self.resetDate = resetDate
    }
}

/// TouchBar 每行末尾的辅助信息：
/// 5 小时行显示 MCP 工具剩余次数，周窗行显示订阅档位。
struct ZCodeUsageSummary: Equatable {
    let mcpRemaining: Int?
    let level: String?

    var fiveHourUsageText: String {
        "工具 \(mcpRemaining.map(String.init) ?? "--")"
    }

    var weeklyUsageText: String {
        "档位 \(level ?? "--")"
    }
}

struct RateLimitDisplayState: Equatable {
    var fiveHour: LimitMeter?
    var weekly: LimitMeter?
    var usage: ZCodeUsageSummary?
    var isRefreshing: Bool
    var lastUpdated: Date?
    var errorMessage: String?

    static let initial = RateLimitDisplayState(
        fiveHour: nil,
        weekly: nil,
        usage: nil,
        isRefreshing: false,
        lastUpdated: nil,
        errorMessage: nil
    )

    var statusText: String {
        if let errorMessage {
            return errorMessage
        }

        if isRefreshing {
            return lastUpdated == nil ? "正在读取 ZCode 额度..." : "正在刷新，保留上一组数据"
        }

        guard let lastUpdated else {
            return "尚未读取额度"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "上次更新 \(formatter.string(from: lastUpdated))"
    }
}
