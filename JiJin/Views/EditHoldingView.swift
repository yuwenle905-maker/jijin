import SwiftUI

// MARK: - 编辑持仓（极简版）
// 场外基金：只填"当前市值"，累计投入自动从记录计算
// 场内ETF：填"持有手数"+"均价成本"，当前市值用实时价格自动计算
struct EditHoldingView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    let fund: Fund
    @State private var holdingValue = ""
    @State private var holdingLots  = ""
    @State private var averageCost  = ""

    var body: some View {
        NavigationView {
            Form {
                // 基金标题
                Section {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4).fill(fund.color).frame(width: 4, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fund.name).font(.headline)
                            Text(fund.code).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                if fund.isETF {
                    // 场内ETF：填手数+均价，当前市值由实时价格算
                    Section {
                        HStack {
                            Text("持有手数")
                            Spacer()
                            TextField("0", text: $holdingLots)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("手").foregroundColor(.secondary)
                        }
                        HStack {
                            Text("均价成本")
                            Spacer()
                            TextField("0.0000", text: $averageCost)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("元/股").foregroundColor(.secondary)
                        }
                    } header: {
                        Text("场内ETF持仓")
                    } footer: {
                        Text("均价成本可在券商App「持仓」页面查看")
                            .font(.caption)
                    }

                    // ETF自动计算展示
                    if let lots = Int(holdingLots), lots > 0, let avg = Double(averageCost), avg > 0 {
                        Section("自动估算") {
                            infoRow("总成本", value: "¥\(Int(Double(lots) * 100 * avg))")
                            infoRow("持有股数", value: "\(lots * 100) 股")
                        }
                    }

                } else {
                    // 场外基金：只填当前市值
                    Section {
                        HStack {
                            Text("当前市值")
                            Spacer()
                            TextField("从券商App抄入", text: $holdingValue)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 130)
                            Text("元").foregroundColor(.secondary)
                        }
                    } header: {
                        Text("场外基金持仓")
                    } footer: {
                        Text("打开东方财富 → 理财资产 → 查看「金额」数字填入")
                            .font(.caption)
                    }

                    // 自动计算信息
                    Section("自动计算") {
                        infoRow("累计投入", value: "¥\(Int(fund.holdingCost))",
                                note: "从定投记录自动汇总")
                        if let v = Double(holdingValue), fund.holdingCost > 0, v > 0 {
                            let pnl  = v - fund.holdingCost
                            let pct  = pnl / fund.holdingCost * 100
                            infoRow("持仓盈亏",
                                    value: String(format: "%+.2f 元", pnl),
                                    color: pnl >= 0 ? .green : .red)
                            infoRow("持仓收益率",
                                    value: String(format: "%+.2f%%", pct),
                                    color: pnl >= 0 ? .green : .red)
                        }
                    }
                }
            }
            .navigationTitle("编辑持仓")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: 信息行（只读）
    private func infoRow(_ label: String, value: String,
                         note: String? = nil, color: Color = .primary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                if let n = note {
                    Text(n).font(.caption2).foregroundColor(.secondary)
                }
            }
            Spacer()
            Text(value).foregroundColor(color).bold()
        }
    }

    private func prefill() {
        holdingValue = fund.holdingValue > 0 ? String(format: "%.2f", fund.holdingValue) : ""
        holdingLots  = fund.holdingLots  > 0 ? "\(fund.holdingLots)" : ""
        averageCost  = fund.averageCost  > 0 ? String(format: "%.4f", fund.averageCost) : ""
    }

    private func save() {
        if fund.isETF {
            store.updateETFHolding(
                fundID: fund.id,
                holdingLots: Int(holdingLots) ?? fund.holdingLots,
                averageCost: Double(averageCost) ?? fund.averageCost
            )
        } else {
            store.updateHoldingValue(
                fundID: fund.id,
                holdingValue: Double(holdingValue) ?? fund.holdingValue
            )
        }
        dismiss()
    }
}
