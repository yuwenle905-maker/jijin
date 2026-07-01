import SwiftUI

// 点击基金卡片进入：显示持仓详情 + 按月分组的定投记录
struct FundDetailView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var priceService: PriceService
    let fund: Fund
    @State private var showEditHolding = false
    @State private var editingRecord: InvestmentRecord? = nil

    var priceInfo: PriceInfo? { priceService.prices[fund.code] }

    // 当前市值（ETF用实时价×股数，场外用用户填入值）
    var currentValue: Double {
        if fund.isETF, let p = priceInfo {
            return Double(fund.holdingShares) * p.estimatedNAV
        }
        return fund.holdingValue
    }

    var body: some View {
        List {
            // ── 价格卡 ──
            Section {
                priceSection
            }

            // ── 持仓卡 ──
            Section {
                holdingSection
            } header: {
                HStack {
                    Text("持仓详情")
                    Spacer()
                    Button("编辑持仓") { showEditHolding = true }
                        .font(.caption)
                }
            }

            // ── 月度记录 ──
            let monthGroups = store.recordsByMonth(for: fund)
            if monthGroups.isEmpty {
                Section("定投记录") {
                    Text("暂无记录").foregroundColor(.secondary)
                }
            } else {
                ForEach(monthGroups, id: \.0) { month, recs in
                    Section {
                        ForEach(recs) { record in
                            RecordDetailRow(record: record)
                                .contentShape(Rectangle())
                                .onTapGesture { editingRecord = record }
                        }
                    } header: {
                        HStack {
                            Text(month)
                            Spacer()
                            let total = recs.filter { $0.status == .success || $0.status == .partial }
                                           .reduce(0) { $0 + $1.actualAmount }
                            if total > 0 {
                                Text("合计 ¥\(Int(total))").font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(fund.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditHolding) {
            EditHoldingView(fund: store.fund(for: fund.id) ?? fund)
                .environmentObject(store)
        }
        .sheet(item: $editingRecord) { record in
            EditRecordView(fund: fund, existingRecord: record)
                .environmentObject(store)
        }
    }

    // MARK: 价格行
    @ViewBuilder private var priceSection: some View {
        if let p = priceInfo {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: "%.4f", p.estimatedNAV))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    HStack(spacing: 6) {
                        changeBadge(p.changePercent)
                        Text("昨日 \(String(format: "%.4f", p.yesterdayNAV))")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if p.isHighPosition {
                        Text("⚠️ 高位信号").font(.caption).foregroundColor(.red)
                    }
                    Text(p.updateTime.isEmpty ? "" : "更新 \(p.updateTime.suffix(5))")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } else {
            HStack {
                Text("行情加载中...")
                    .foregroundColor(.secondary)
                Spacer()
                ProgressView()
            }
        }
    }

    // MARK: 持仓行
    @ViewBuilder private var holdingSection: some View {
        let hasCost = fund.holdingCost > 0
        let hasValue = currentValue > 0

        if fund.isETF {
            infoRow("持有股数", value: fund.holdingShares > 0
                ? "\(fund.holdingShares) 股（\(fund.holdingShares / 100) 手）" : "—")
            infoRow("成本价",   value: fund.averageCost > 0
                ? String(format: "%.4f 元/股", fund.averageCost) : "—")
            if hasValue {
                infoRow("当前估值", value: String(format: "¥%.2f", currentValue))
            }
            if fund.holdingShares > 0, fund.averageCost > 0, let p = priceInfo {
                let pnl = Double(fund.holdingShares) * (p.estimatedNAV - fund.averageCost)
                let pct = (p.estimatedNAV - fund.averageCost) / fund.averageCost * 100
                infoRow("持仓盈亏", value: String(format: "%+.2f 元  %+.2f%%", pnl, pct),
                        color: pnl >= 0 ? .green : .red)
            }
        } else {
            if hasValue {
                infoRow("当前市值", value: String(format: "¥%.2f", currentValue))
            } else {
                HStack {
                    Text("当前市值").foregroundColor(.secondary)
                    Spacer()
                    Text("未设置  →  点击右上角编辑持仓").font(.caption).foregroundColor(.orange)
                }
            }
            if hasCost {
                infoRow("累计投入", value: String(format: "¥%.2f", fund.holdingCost),
                        note: "自动汇总")
            }
            if hasValue && hasCost {
                let pnl = currentValue - fund.holdingCost
                let pct = pnl / fund.holdingCost * 100
                infoRow("持仓收益", value: String(format: "%+.2f 元  %+.2f%%", pnl, pct),
                        color: pnl >= 0 ? .green : .red)
            }
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
            Text(value).foregroundColor(color)
        }
    }

    private func changeBadge(_ pct: Double) -> some View {
        Text(String(format: "%+.2f%%", pct))
            .font(.subheadline.bold().monospacedDigit())
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(pct >= 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
            .foregroundColor(pct >= 0 ? .green : .red)
            .cornerRadius(4)
    }
}

// MARK: - 单条记录行（详情页内用）
struct RecordDetailRow: View {
    let record: InvestmentRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: record.status.icon)
                .foregroundColor(record.status.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.date, style: .date)
                    .font(.subheadline)
                if let note = record.note {
                    Text(note).font(.caption2).foregroundColor(.orange)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if record.actualAmount > 0 {
                    Text(String(format: "¥%.2f", record.actualAmount))
                        .font(.subheadline)
                }
                Text(record.status.rawValue)
                    .font(.caption2)
                    .foregroundColor(record.status.color)
            }

            Image(systemName: "chevron.right")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
