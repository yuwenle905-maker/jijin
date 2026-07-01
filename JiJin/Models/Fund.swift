import Foundation
import SwiftUI

// MARK: - 基金定义
struct Fund: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var code: String
    var colorHex: String          // SwiftUI Color from hex
    var scheduleDays: [Int]       // 1=周一 … 7=周日
    var dcaAmount: Double         // 定投金额（ETF场内基金填0）
    var isETF: Bool               // 场内ETF（需手动下单）
    var etfTime: String?          // 操作时间 e.g. "14:50"
    var etfLots: Int?             // 手数 e.g. 100
    var targetMinPct: Double?     // 再平衡目标下限 0~1
    var targetMaxPct: Double?     // 再平衡目标上限 0~1
    var isRebalanceTarget: Bool = true  // 纳入再平衡计算

    var color: Color { Color(hex: colorHex) ?? .blue }
    var scheduleText: String {
        let days = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        return scheduleDays.map { days[$0] }.joined(separator: "、")
    }
    var actionText: String {
        if isETF, let time = etfTime, let lots = etfLots {
            return "\(time) 限时卖一价买入 \(lots) 手"
        }
        return "定投 \(Int(dcaAmount)) 元"
    }
}

// MARK: - 投资记录状态
enum RecordStatus: String, Codable, CaseIterable {
    case success  = "成功"
    case failed   = "余额不足"
    case partial  = "部分成交"
    case skipped  = "跳过"
}

extension RecordStatus {
    var color: Color {
        switch self {
        case .success: return .green
        case .failed:  return .red
        case .partial: return .orange
        case .skipped: return .secondary
        }
    }
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failed:  return "exclamationmark.circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .skipped: return "minus.circle.fill"
        }
    }
}

// MARK: - 投资记录
struct InvestmentRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var fundID: UUID
    var date: Date
    var plannedAmount: Double   // 计划金额（手数×价格 或 定投额）
    var actualAmount: Double    // 实际成交金额
    var units: Double?          // 成交份数/股数
    var price: Double?          // 成交价/净值
    var status: RecordStatus
    var note: String?
}

// MARK: - Color Hex 扩展
extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if h.count == 6 { h = "FF" + h }
        guard h.count == 8, let val = UInt64(h, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red:     Double((val >> 16) & 0xFF) / 255,
            green:   Double((val >>  8) & 0xFF) / 255,
            blue:    Double( val        & 0xFF) / 255,
            opacity: Double((val >> 24) & 0xFF) / 255
        )
    }
}
