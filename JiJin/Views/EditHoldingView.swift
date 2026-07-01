import SwiftUI

// MARK: - 编辑持仓信息
struct EditHoldingView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    let fund: Fund
    @State private var holdingValue  = ""
    @State private var holdingCost   = ""
    @State private var holdingLots   = ""
    @State private var averageCost   = ""

    var body: some View {
        NavigationView {
            Form {
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
                    Section("场内ETF持仓") {
                        numRow("当前持有", value: $holdingLots, unit: "手")
                        numRow("均价成本", value: $averageCost, unit: "元/股")
                    }
                    if let lots = Int(holdingLots), let avg = Double(averageCost), lots > 0, avg > 0 {
                        Section("估算") {
                            let totalCost = Double(lots) * 100 * avg
                            HStack {
                                Text("总成本")
                                Spacer()
                                Text("¥\(Int(totalCost))").foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    Section("场外基金持仓") {
                        numRow("当前市值", value: $holdingValue, unit: "元",
                               placeholder: "按最新净值×份数估算")
                        numRow("累计投入", value: $holdingCost, unit: "元",
                               placeholder: "所有定投金额之和")
                    }
                    if let v = Double(holdingValue), let c = Double(holdingCost), c > 0 {
                        Section("估算") {
                            let pnl = v - c
                            let pct = pnl / c * 100
                            HStack {
                                Text("盈亏")
                                Spacer()
                                Text(pnl >= 0 ? "+¥\(Int(pnl))" : "-¥\(Int(abs(pnl)))")
                                    .foregroundColor(pnl >= 0 ? .green : .red)
                            }
                            HStack {
                                Text("收益率")
                                Spacer()
                                Text(String(format: "%+.2f%%", pct))
                                    .foregroundColor(pnl >= 0 ? .green : .red)
                            }
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

    private func numRow(_ label: String, value: Binding<String>, unit: String, placeholder: String = "0") -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
            Text(unit).foregroundColor(.secondary)
        }
    }

    private func prefill() {
        holdingValue = fund.holdingValue > 0 ? "\(Int(fund.holdingValue))" : ""
        holdingCost  = fund.holdingCost  > 0 ? "\(Int(fund.holdingCost))"  : ""
        holdingLots  = fund.holdingLots  > 0 ? "\(fund.holdingLots)"       : ""
        averageCost  = fund.averageCost  > 0 ? String(format: "%.4f", fund.averageCost) : ""
    }

    private func save() {
        let v    = Double(holdingValue)  ?? fund.holdingValue
        let c    = Double(holdingCost)   ?? fund.holdingCost
        let lots = Int(holdingLots)      ?? fund.holdingLots
        let avg  = Double(averageCost)   ?? fund.averageCost
        store.updateHolding(fundID: fund.id, holdingValue: v, holdingCost: c,
                            holdingLots: lots, averageCost: avg)
        dismiss()
    }
}
