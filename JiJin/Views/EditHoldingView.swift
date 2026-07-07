import SwiftUI

struct EditHoldingView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    let fund: Fund
    @State private var holdingValue  = ""
    @State private var holdingShares = ""
    @State private var averageCost   = ""
    @State private var manualCostStr = ""   // 场外基金：用户手填的累计投入

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
                    Section {
                        HStack {
                            Text("持有股数")
                            Spacer()
                            TextField("0", text: $holdingShares)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("股").foregroundColor(.secondary)
                        }
                        HStack {
                            Text("成本价")
                            Spacer()
                            TextField("0.000", text: $averageCost)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("元/股").foregroundColor(.secondary)
                        }
                    } header: {
                        Text("场内ETF持仓")
                    } footer: {
                        Text("股数和成本价均可在券商App「持仓明细」页面查看\n1手 = 100股，例如持有400股请填 400")
                            .font(.caption)
                    }

                    if let shares = Int(holdingShares), shares > 0,
                       let avg = Double(averageCost), avg > 0 {
                        Section("自动估算") {
                            infoRow("总成本", value: String(format: "¥%.2f", Double(shares) * avg))
                            infoRow("折合手数", value: "\(shares / 100) 手 \(shares % 100 > 0 ? "+ \(shares % 100)股" : "")")
                        }
                    }

                } else {
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
                        HStack {
                            Text("累计投入")
                            Spacer()
                            TextField("实际投入总金额", text: $manualCostStr)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 130)
                            Text("元").foregroundColor(.secondary)
                        }
                    } header: {
                        Text("场外基金持仓")
                    } footer: {
                        Text("市值：东方财富 → 理财资产 → 对应基金的「金额」\n累计投入：东方财富 → 持仓 → 对应基金的「累计投入」")
                            .font(.caption)
                    }

                    if let v = Double(holdingValue), let c = Double(manualCostStr), c > 0, v > 0 {
                        let pnl = v - c
                        let pct = pnl / c * 100
                        Section("预览") {
                            infoRow("持仓收益", value: String(format: "%+.2f 元", pnl),
                                    color: pnl >= 0 ? .green : .red)
                            infoRow("收益率", value: String(format: "%+.2f%%", pct),
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

    private func infoRow(_ label: String, value: String,
                         note: String? = nil, color: Color = .primary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                if let n = note { Text(n).font(.caption2).foregroundColor(.secondary) }
            }
            Spacer()
            Text(value).foregroundColor(color).bold()
        }
    }

    private func prefill() {
        holdingValue  = fund.holdingValue  > 0 ? String(format: "%.2f", fund.holdingValue) : ""
        holdingShares = fund.holdingShares > 0 ? "\(fund.holdingShares)" : ""
        averageCost   = fund.averageCost   > 0 ? String(format: "%.4f", fund.averageCost)  : ""
        // 优先用手动值，否则用自动汇总值（如有）作为参考预填
        let costRef = fund.manualCost ?? (fund.holdingCost > 0 ? fund.holdingCost : nil)
        manualCostStr = costRef.map { String(format: "%.2f", $0) } ?? ""
    }

    private func save() {
        if fund.isETF {
            store.updateETFHolding(
                fundID: fund.id,
                holdingShares: Int(holdingShares) ?? fund.holdingShares,
                averageCost:   Double(averageCost) ?? fund.averageCost)
        } else {
            store.updateHoldingValue(
                fundID: fund.id,
                holdingValue: Double(holdingValue) ?? fund.holdingValue,
                manualCost: Double(manualCostStr))
        }
        dismiss()
    }
}
