import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var priceService: PriceService
    @State private var editingRecord: (Fund, InvestmentRecord)? = nil

    // 计算总持仓（ETF用实时价，场外用用户填入值）
    var totalValue: Double {
        store.funds.reduce(0.0) { sum, fund in
            if fund.isETF {
                let price = priceService.prices[fund.code]?.estimatedNAV ?? 0
                return sum + Double(fund.holdingShares) * price
            }
            return sum + fund.holdingValue
        }
    }
    var totalCost: Double { store.funds.reduce(0) { $0 + $1.holdingCost } }

    var body: some View {
        NavigationView {
            List {
                summarySection
                fundListSection
                if !todayFunds.isEmpty { todayTaskSection }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("定投管家")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        priceService.fetchAll(codes: store.funds.map(\.code))
                    } label: {
                        if priceService.isLoading { ProgressView().scaleEffect(0.75) }
                        else { Image(systemName: "arrow.clockwise") }
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
        }
    }

    // MARK: 总资产摘要
    private var summarySection: some View {
        Section {
            VStack(spacing: 10) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("总持仓市值").font(.caption).foregroundColor(.secondary)
                        Text(String(format: "¥%.2f", totalValue))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    if totalCost > 0 && totalValue > 0 {
                        let pnl = totalValue - totalCost
                        let pct = pnl / totalCost * 100
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("持仓收益").font(.caption).foregroundColor(.secondary)
                            Text(String(format: "%+.2f", pnl))
                                .font(.title3.bold())
                                .foregroundColor(pnl >= 0 ? .green : .red)
                            Text(String(format: "%+.2f%%", pct))
                                .font(.caption.bold())
                                .foregroundColor(pnl >= 0 ? .green : .red)
                        }
                    }
                }
                HStack {
                    Label(
                        priceService.lastUpdated.map { "行情 \(timeStr($0))" } ?? "点击刷新行情",
                        systemImage: priceService.lastUpdated != nil ? "wifi" : "wifi.slash"
                    )
                    .font(.caption2)
                    .foregroundColor(priceService.lastUpdated != nil ? .green : .secondary)
                    Spacer()
                    if totalCost > 0 {
                        Text("累计投入 ¥\(Int(totalCost))").font(.caption2).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: 基金持仓列表（点击进详情）
    private var fundListSection: some View {
        Section("持仓基金") {
            ForEach(store.funds) { fund in
                NavigationLink(destination:
                    FundDetailView(fund: fund)
                        .environmentObject(store)
                        .environmentObject(priceService)
                ) {
                    FundRow(fund: fund,
                            priceInfo: priceService.prices[fund.code],
                            currentValue: currentValue(for: fund))
                }
            }
        }
    }

    // MARK: 今日任务
    private var todayTaskSection: some View {
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

    // MARK: Helpers
    func currentValue(for fund: Fund) -> Double {
        if fund.isETF {
            let price = priceService.prices[fund.code]?.estimatedNAV ?? 0
            return Double(fund.holdingShares) * price
        }
        return fund.holdingValue
    }

    private var todayFunds: [Fund] { store.fundsForToday() }
    private var todayDateStr: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }
    private func timeStr(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
    private var editingRecordBinding: Binding<FundRecordPair?> {
        Binding(
            get: { editingRecord.map { FundRecordPair(fund: $0.0, record: $0.1) } },
            set: { editingRecord = $0.map { ($0.fund, $0.record) } }
        )
    }
}

// MARK: - 基金行（列表用）
struct FundRow: View {
    let fund: Fund
    let priceInfo: PriceInfo?
    let currentValue: Double

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(fund.color).frame(width: 3, height: 50)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(fund.name).font(.subheadline.bold()).lineLimit(1)
                    if let p = priceInfo, p.isHighPosition {
                        Text("高位").font(.caption2)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.red.opacity(0.12)).foregroundColor(.red).cornerRadius(3)
                    }
                }
                HStack(spacing: 6) {
                    Text(fund.code).font(.caption2).foregroundColor(.secondary)
                    if let p = priceInfo {
                        Text(String(format: "%.4f", p.estimatedNAV))
                            .font(.caption2.monospacedDigit()).foregroundColor(.secondary)
                        changeBadge(p.changePercent)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if currentValue > 0 {
                    Text(String(format: "¥%.2f", currentValue)).font(.subheadline.bold())
                    pnlView
                } else if fund.isETF && fund.holdingShares == 0 {
                    Text("未设置").font(.caption).foregroundColor(.secondary)
                } else if !fund.isETF && fund.holdingValue == 0 && fund.holdingCost > 0 {
                    Text("未更新市值").font(.caption).foregroundColor(.orange)
                } else {
                    Text("—").foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder private var pnlView: some View {
        if fund.isETF, fund.averageCost > 0, let p = priceInfo, fund.holdingShares > 0 {
            let pct = (p.estimatedNAV - fund.averageCost) / fund.averageCost * 100
            Text(String(format: "%+.2f%%", pct))
                .font(.caption.bold().monospacedDigit())
                .foregroundColor(pct >= 0 ? .green : .red)
        } else if !fund.isETF, fund.holdingCost > 0, fund.holdingValue > 0 {
            let pct = (fund.holdingValue - fund.holdingCost) / fund.holdingCost * 100
            Text(String(format: "%+.2f%%", pct))
                .font(.caption.bold().monospacedDigit())
                .foregroundColor(pct >= 0 ? .green : .red)
        }
    }

    private func changeBadge(_ pct: Double) -> some View {
        Text(String(format: "%+.2f%%", pct))
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(pct >= 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
            .foregroundColor(pct >= 0 ? .green : .red).cornerRadius(3)
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
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct FundRecordPair: Identifiable {
    let id = UUID()
    let fund: Fund
    let record: InvestmentRecord
}
