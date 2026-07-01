import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var priceService: PriceService
    @State private var editingRecord: (Fund, InvestmentRecord)? = nil
    @State private var editingHolding: Fund? = nil

    var body: some View {
        NavigationView {
            List {
                // ── 总资产摘要 ──
                summarySection

                // ── 各基金持仓（图二样式）──
                Section("持仓基金") {
                    ForEach(store.funds) { fund in
                        FundRow(fund: fund, priceInfo: priceService.prices[fund.code])
                            .contentShape(Rectangle())
                            .onTapGesture { editingHolding = fund }
                    }
                }

                // ── 今日任务 ──
                if !todayFunds.isEmpty {
                    Section("今日任务  \(todayDateStr)") {
                        ForEach(todayFunds) { fund in
                            if let record = store.record(for: fund, on: Date()) {
                                TodayTaskRow(fund: fund, record: record)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingRecord = (fund, record) }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("定投管家")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        priceService.fetchAll(codes: store.funds.map(\.code))
                    } label: {
                        if priceService.isLoading {
                            ProgressView().scaleEffect(0.75)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear {
                store.autoGenerateTodayRecords()
                priceService.fetchAll(codes: store.funds.map(\.code))
            }
            .sheet(item: editingRecordBinding) { pair in
                EditRecordView(fund: pair.fund, existingRecord: pair.record)
                    .environmentObject(store)
            }
            .sheet(item: $editingHolding) { fund in
                EditHoldingView(fund: fund)
                    .environmentObject(store)
            }
        }
    }

    // MARK: - 总资产摘要
    private var summarySection: some View {
        Section {
            VStack(spacing: 12) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("总持仓市值").font(.caption).foregroundColor(.secondary)
                        Text("¥\(String(format: "%.2f", store.totalHoldingValue))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    if store.totalHoldingCost > 0 && store.totalHoldingValue > 0 {
                        let pnl    = store.totalHoldingValue - store.totalHoldingCost
                        let pnlPct = pnl / store.totalHoldingCost * 100
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("持仓收益").font(.caption).foregroundColor(.secondary)
                            Text(String(format: "%+.2f", pnl))
                                .font(.title3.bold())
                                .foregroundColor(pnl >= 0 ? .green : .red)
                            Text(String(format: "%+.2f%%", pnlPct))
                                .font(.caption.bold())
                                .foregroundColor(pnl >= 0 ? .green : .red)
                        }
                    }
                }

                HStack {
                    Label(
                        priceService.lastUpdated.map { "行情更新 \(timeStr($0))" } ?? "点击右上角刷新行情",
                        systemImage: priceService.lastUpdated != nil ? "wifi" : "wifi.slash"
                    )
                    .font(.caption2)
                    .foregroundColor(priceService.lastUpdated != nil ? Color.green : .secondary)
                    Spacer()
                    Text("累计投入 ¥\(Int(store.totalHoldingCost))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: Helpers
    private var todayFunds: [Fund] { store.fundsForToday() }
    private var todayDateStr: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }
    private func timeStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }
    private var editingRecordBinding: Binding<FundRecordPair?> {
        Binding(
            get: { editingRecord.map { FundRecordPair(fund: $0.0, record: $0.1) } },
            set: { editingRecord = $0.map { ($0.fund, $0.record) } }
        )
    }
}

// MARK: - 基金持仓行（仿图二样式）
struct FundRow: View {
    let fund: Fund
    let priceInfo: PriceInfo?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                // 左：色条
                RoundedRectangle(cornerRadius: 3)
                    .fill(fund.color)
                    .frame(width: 3, height: 44)

                // 中：名称 + 代码 + 行情
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(fund.name)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        if let info = priceInfo, info.isHighPosition {
                            Text("高位")
                                .font(.caption2)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color.red.opacity(0.12))
                                .foregroundColor(.red)
                                .cornerRadius(3)
                        }
                    }
                    HStack(spacing: 6) {
                        Text(fund.code)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let info = priceInfo {
                            Text(String(format: "%.4f", info.estimatedNAV))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.secondary)
                            changeBadge(info.changePercent)
                        }
                    }
                }

                Spacer()

                // 右：持仓金额 + 收益
                VStack(alignment: .trailing, spacing: 3) {
                    holdingValueText
                    holdingPnlText
                }
            }

            // 待确认定投提示
            if let pendingAmount = pendingAmount {
                HStack {
                    Spacer().frame(width: 13)
                    Text("买入待确认 \(String(format: "%.2f", pendingAmount)) 元")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }

    // 持仓金额显示
    @ViewBuilder private var holdingValueText: some View {
        if fund.isETF {
            if fund.holdingLots > 0 {
                if let info = priceInfo {
                    // 实时估算 = 手数 × 100 × 当前价
                    let val = Double(fund.holdingLots) * 100 * info.estimatedNAV
                    Text(String(format: "%.2f", val))
                        .font(.subheadline.bold())
                } else {
                    Text("\(fund.holdingLots) 手")
                        .font(.subheadline.bold())
                }
            } else {
                Text("未设置持仓")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } else {
            if fund.holdingValue > 0 {
                Text(String(format: "%.2f", fund.holdingValue))
                    .font(.subheadline.bold())
            } else if fund.holdingCost > 0 {
                Text("未更新市值")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("—")
                    .foregroundColor(.secondary)
            }
        }
    }

    // 持仓收益率显示
    @ViewBuilder private var holdingPnlText: some View {
        if fund.isETF, fund.holdingLots > 0, fund.averageCost > 0, let info = priceInfo {
            let pct = (info.estimatedNAV - fund.averageCost) / fund.averageCost * 100
            let pnl = Double(fund.holdingLots) * 100 * (info.estimatedNAV - fund.averageCost)
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%+.2f", pnl))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(pct >= 0 ? .green : .red)
                Text(String(format: "%+.2f%%", pct))
                    .font(.caption.bold())
                    .foregroundColor(pct >= 0 ? .green : .red)
            }
        } else if !fund.isETF, fund.holdingValue > 0, fund.holdingCost > 0 {
            let pnl = fund.holdingValue - fund.holdingCost
            let pct = pnl / fund.holdingCost * 100
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%+.2f", pnl))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(pct >= 0 ? .green : .red)
                Text(String(format: "%+.2f%%", pct))
                    .font(.caption.bold())
                    .foregroundColor(pct >= 0 ? .green : .red)
            }
        }
    }

    // 待确认金额（今日 pending 记录）
    private var pendingAmount: Double? {
        // 这里只是标记展示，真实数据在 store 里；TodayView 直接传来更好
        // 简化：不在这里查 store，由 TodayView 统一处理
        nil
    }

    private func changeBadge(_ pct: Double) -> some View {
        Text(String(format: "%+.2f%%", pct))
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(pct >= 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
            .foregroundColor(pct >= 0 ? .green : .red)
            .cornerRadius(3)
    }
}

// MARK: - 今日任务行
struct TodayTaskRow: View {
    let fund: Fund
    let record: InvestmentRecord

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(fund.color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(fund.name).font(.subheadline)
                Text(fund.actionText).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: record.status.icon)
                Text(record.status.rawValue).font(.caption)
            }
            .foregroundColor(record.status.color)
            Image(systemName: "chevron.right")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Identifiable wrapper
struct FundRecordPair: Identifiable {
    let id = UUID()
    let fund: Fund
    let record: InvestmentRecord
}
