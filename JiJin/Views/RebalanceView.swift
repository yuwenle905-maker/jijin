import SwiftUI

struct RebalanceView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var priceService: PriceService

    // 当前各基金市值（自动从首页数据读取）
    func currentValue(for fund: Fund) -> Double {
        if fund.isETF {
            let price = priceService.prices[fund.code]?.estimatedNAV ?? 0
            return Double(fund.holdingShares) * price
        }
        return fund.holdingValue
    }

    var totalValue: Double { store.funds.reduce(0) { $0 + currentValue(for: $1) } }
    var rebalanceFunds: [Fund] { store.funds.filter { $0.isRebalanceTarget } }

    var body: some View {
        NavigationView {
            List {
                // 数据来源说明
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill").foregroundColor(.blue)
                        Text("持仓数据已自动从首页读取，无需手动输入")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if totalValue == 0 {
                        Text("请先在首页设置各基金持仓，ETF填写股数，场外基金同步市值")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if totalValue > 0 {
                    // 当前持仓分布
                    Section("当前持仓分布") {
                        ForEach(store.funds) { fund in
                            let val = currentValue(for: fund)
                            let pct = totalValue > 0 ? val / totalValue * 100 : 0
                            HStack(spacing: 10) {
                                Circle().fill(fund.color).frame(width: 8, height: 8)
                                Text(fund.name).font(.subheadline).lineLimit(1)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(String(format: "¥%.0f", val)).font(.subheadline)
                                    Text(String(format: "%.1f%%", pct)).font(.caption)
                                        .foregroundColor(targetStatus(fund: fund, pct: pct / 100))
                                }
                            }
                        }
                    }

                    // 再平衡建议
                    Section("再平衡建议") {
                        let suggestions = buildSuggestions()
                        if suggestions.isEmpty {
                            Label("各资产占比在目标区间内，无需操作", systemImage: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        } else {
                            ForEach(suggestions) { s in
                                HStack(spacing: 10) {
                                    Image(systemName: s.isBuy ? "plus.circle.fill" : "minus.circle.fill")
                                        .foregroundColor(s.isBuy ? .green : .red)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.fund.name).font(.subheadline.bold())
                                        Text(s.reason).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(s.isBuy ? "+¥\(Int(s.amount))" : "-¥\(Int(s.amount))")
                                        .font(.subheadline.bold())
                                        .foregroundColor(s.isBuy ? .green : .red)
                                }
                            }
                        }
                    }

                    // 组合概览
                    Section("组合概览") {
                        infoRow("总持仓", value: String(format: "¥%.2f", totalValue))
                        let equity = rebalanceFunds.reduce(0.0) { $0 + currentValue(for: $1) }
                        infoRow("权益资产", value: String(format: "¥%.0f (%.1f%%)", equity, equity/totalValue*100))
                        infoRow("债券+黄金", value: String(format: "¥%.0f (%.1f%%)",
                            totalValue - equity, (totalValue - equity)/totalValue*100))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("再平衡")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        priceService.fetchAll(codes: store.funds.map(\.code))
                    } label: { Image(systemName: "arrow.clockwise") }
                }
            }
        }
    }

    private func targetStatus(fund: Fund, pct: Double) -> Color {
        guard let minP = fund.targetMinPct, let maxP = fund.targetMaxPct else { return .secondary }
        if pct > maxP { return .red }
        if pct < minP { return .orange }
        return .green
    }

    private func buildSuggestions() -> [RebalanceSuggestion] {
        rebalanceFunds.compactMap { fund in
            guard let minP = fund.targetMinPct, let maxP = fund.targetMaxPct else { return nil }
            let cur = totalValue > 0 ? currentValue(for: fund) / totalValue : 0
            if cur > maxP {
                return RebalanceSuggestion(fund: fund, isBuy: false, amount: (cur - maxP) * totalValue,
                    reason: "当前 \(pctStr(cur))，超出上限 \(pctStr(maxP))")
            } else if cur < minP {
                return RebalanceSuggestion(fund: fund, isBuy: true, amount: (minP - cur) * totalValue,
                    reason: "当前 \(pctStr(cur))，低于下限 \(pctStr(minP))")
            }
            return nil
        }
    }

    private func pctStr(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundColor(.secondary) }
    }
}

struct RebalanceSuggestion: Identifiable {
    let id = UUID()
    let fund: Fund
    let isBuy: Bool
    let amount: Double
    let reason: String
}
