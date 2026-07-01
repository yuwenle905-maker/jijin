import SwiftUI

// MARK: - 设置：修改基金配置
struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @State private var editingFund: Fund? = nil

    var body: some View {
        NavigationView {
            List {
                Section("我的基金计划") {
                    ForEach(store.funds) { fund in
                        FundSettingsRow(fund: fund)
                            .contentShape(Rectangle())
                            .onTapGesture { editingFund = fund }
                    }
                }

                Section("定投准则") {
                    principleRow(icon: "infinity", text: "永不清仓权益资产")
                    principleRow(icon: "calendar", text: "每年12月执行再平衡")
                    principleRow(icon: "chart.line.flattrend.xyaxis", text: "不设止盈，长期持有")
                    principleRow(icon: "moon.zzz", text: "日常不盯盘，年度思维")
                }

                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
            .sheet(item: $editingFund) { fund in
                EditFundView(fund: fund)
                    .environmentObject(store)
            }
        }
    }

    private func principleRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - 基金设置行
struct FundSettingsRow: View {
    let fund: Fund

    private var assetType: String {
        switch fund.code {
        case "513500": return "国际权益"
        case "008114": return "稳健权益"
        case "022459": return "成长权益"
        case "110017": return "固收+"
        case "000216": return "硬资产"
        default:       return ""
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(fund.color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(fund.name).font(.subheadline.bold())
                    if !assetType.isEmpty {
                        Text("(\(assetType))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text("\(fund.scheduleText)  \(fund.actionText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 编辑基金配置
struct EditFundView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    @State var fund: Fund

    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    HStack { Text("基金名称"); Spacer(); Text(fund.name).foregroundColor(.secondary) }
                    HStack { Text("基金代码"); Spacer(); Text(fund.code).foregroundColor(.secondary) }
                }

                if fund.isETF {
                    Section("场内ETF设置") {
                        HStack {
                            Text("操作时间")
                            Spacer()
                            TextField("14:50", text: Binding(
                                get: { fund.etfTime ?? "" },
                                set: { fund.etfTime = $0 }
                            ))
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        }
                        HStack {
                            Text("买入手数")
                            Spacer()
                            TextField("100", text: Binding(
                                get: { fund.etfLots.map { "\($0)" } ?? "" },
                                set: { fund.etfLots = Int($0) }
                            ))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            Text("手")
                        }
                    }
                } else {
                    Section("定投设置") {
                        HStack {
                            Text("定投金额")
                            Spacer()
                            TextField("0", text: Binding(
                                get: { "\(Int(fund.dcaAmount))" },
                                set: { fund.dcaAmount = Double($0) ?? fund.dcaAmount }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            Text("元")
                        }
                    }
                }

                if let minP = fund.targetMinPct, let maxP = fund.targetMaxPct {
                    Section("再平衡目标区间") {
                        HStack {
                            Text("下限")
                            Spacer()
                            TextField("0", text: Binding(
                                get: { String(format: "%.0f", minP * 100) },
                                set: { fund.targetMinPct = (Double($0) ?? (minP * 100)) / 100 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            Text("%")
                        }
                        HStack {
                            Text("上限")
                            Spacer()
                            TextField("0", text: Binding(
                                get: { String(format: "%.0f", maxP * 100) },
                                set: { fund.targetMaxPct = (Double($0) ?? (maxP * 100)) / 100 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            Text("%")
                        }
                    }
                }
            }
            .navigationTitle("编辑基金")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.updateFund(fund)
                        dismiss()
                    }
                }
            }
        }
    }
}
