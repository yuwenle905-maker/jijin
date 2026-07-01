import SwiftUI

// MARK: - 再平衡计算器
struct RebalanceView: View {
    @EnvironmentObject var store: DataStore
    @State private var values: [UUID: String] = [:]
    @State private var showResult = false

    private var rebalanceFunds: [Fund] { store.funds.filter { $0.isRebalanceTarget } }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("输入各基金当前持仓市值，系统自动计算是否需要再平衡。")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("当前持仓市值") {
                    ForEach(store.funds) { fund in
                        HStack {
                            Circle()
                                .fill(fund.color)
                                .frame(width: 8, height: 8)
                            Text(fund.name)
                                .font(.subheadline)
                            Spacer()
                            TextField("0", text: binding(for: fund.id))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("元")
                        }
                    }
                }

                if totalValue > 0 {
                    Section("当前占比 vs 目标区间") {
                        ForEach(rebalanceFunds) { fund in
                            RebalanceRow(
                                fund: fund,
                                currentPct: pct(for: fund),
                                currentValue: val(for: fund),
                                totalValue: totalValue
                            )
                        }
                    }

                    Section("操作建议") {
                        ForEach(suggestions) { s in
                            HStack(spacing: 8) {
                                Image(systemName: s.action == .buy ? "plus.circle.fill" : "minus.circle.fill")
                                    .foregroundColor(s.action == .buy ? .green : .red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.fund.name).font(.subheadline.bold())
                                    Text(s.reason).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(s.action == .buy ? "+¥\(Int(s.amount))" : "-¥\(Int(s.amount))")
                                    .font(.subheadline.bold())
                                    .foregroundColor(s.action == .buy ? .green : .red)
                            }
                        }
                        if suggestions.isEmpty {
                            Label("各资产占比在目标区间内，无需操作", systemImage: "checkmark.seal.fill")
                                .foregroundColor(.green)
                        }
                    }

                    Section("投资组合概览") {
                        HStack {
                            Text("总市值")
                            Spacer()
                            Text("¥\(Int(totalValue))")
                                .bold()
                        }
                        HStack {
                            Text("权益资产")
                            Spacer()
                            Text("¥\(Int(equityValue))  (\(pctText(equityValue / totalValue)))")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("债券+黄金")
                            Spacer()
                            Text("¥\(Int(totalValue - equityValue))  (\(pctText(1 - equityValue / totalValue)))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("再平衡计算器")
        }
    }

    // MARK: 计算属性
    private var totalValue: Double {
        store.funds.reduce(0) { $0 + val(for: $1) }
    }

    private var equityValue: Double {
        store.funds.filter { $0.isRebalanceTarget }.reduce(0) { $0 + val(for: $1) }
    }

    private func val(for fund: Fund) -> Double {
        Double(values[fund.id] ?? "") ?? 0
    }

    private func pct(for fund: Fund) -> Double {
        guard totalValue > 0 else { return 0 }
        return val(for: fund) / totalValue
    }

    private func pctText(_ v: Double) -> String {
        String(format: "%.1f%%", v * 100)
    }

    // MARK: 再平衡建议
    private var suggestions: [RebalanceSuggestion] {
        var result: [RebalanceSuggestion] = []
        for fund in rebalanceFunds {
            guard let minP = fund.targetMinPct, let maxP = fund.targetMaxPct else { continue }
            let cur = pct(for: fund)
            if cur > maxP {
                let excess = (cur - maxP) * totalValue
                result.append(RebalanceSuggestion(fund: fund, action: .sell, amount: excess,
                    reason: "当前 \(pctText(cur))，超过上限 \(pctText(maxP))"))
            } else if cur < minP {
                let deficit = (minP - cur) * totalValue
                result.append(RebalanceSuggestion(fund: fund, action: .buy, amount: deficit,
                    reason: "当前 \(pctText(cur))，低于下限 \(pctText(minP))"))
            }
        }
        return result
    }

    private func binding(for id: UUID) -> Binding<String> {
        Binding(
            get: { values[id] ?? "" },
            set: { values[id] = $0 }
        )
    }
}

// MARK: - 再平衡行
struct RebalanceRow: View {
    let fund: Fund
    let currentPct: Double
    let currentValue: Double
    let totalValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(fund.color).frame(width: 8, height: 8)
                Text(fund.name).font(.subheadline)
                Spacer()
                Text(pctText(currentPct))
                    .font(.subheadline.bold())
                    .foregroundColor(statusColor)
            }
            if let minP = fund.targetMinPct, let maxP = fund.targetMaxPct {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // 目标区间背景
                        Rectangle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: geo.size.width * CGFloat(maxP - minP) / 0.5)
                            .offset(x: geo.size.width * CGFloat(minP) / 0.5)
                        // 当前占比指示线
                        Rectangle()
                            .fill(statusColor)
                            .frame(width: 2, height: 12)
                            .offset(x: geo.size.width * CGFloat(min(currentPct, 0.5)) / 0.5 - 1)
                    }
                    .frame(height: 12)
                    .background(Color(.systemFill))
                    .cornerRadius(4)
                }
                .frame(height: 12)
                HStack {
                    Text("目标 \(pctText(minP))–\(pctText(maxP))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("¥\(Int(currentValue))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        guard let minP = fund.targetMinPct, let maxP = fund.targetMaxPct else { return .secondary }
        if currentPct > maxP { return .red }
        if currentPct < minP { return .orange }
        return .green
    }

    private func pctText(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }
}

// MARK: - 建议模型
struct RebalanceSuggestion: Identifiable {
    let id = UUID()
    let fund: Fund
    let action: RebalanceAction
    let amount: Double
    let reason: String
}

enum RebalanceAction { case buy, sell }
