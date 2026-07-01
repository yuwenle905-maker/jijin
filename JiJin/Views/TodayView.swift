import SwiftUI

struct TodayView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var priceService: PriceService
    @State private var editingRecord: (Fund, InvestmentRecord)? = nil
    @State private var editingHolding: Fund? = nil

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    portfolioSummaryCard
                    fundCardsSection
                    if !todayFunds.isEmpty {
                        todayTaskSection
                    }
                }
                .padding()
            }
            .navigationTitle("定投管家")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        priceService.fetchAll(codes: store.funds.map(\.code))
                    } label: {
                        if priceService.isLoading {
                            ProgressView().scaleEffect(0.7)
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

    // MARK: - 总持仓摘要卡片
    private var portfolioSummaryCard: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总持仓").font(.caption).foregroundColor(.secondary)
                    Text("¥\(Int(store.totalHoldingValue))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("总盈亏").font(.caption).foregroundColor(.secondary)
                    let pnl = store.totalHoldingValue - store.totalHoldingCost
                    let pnlPct = store.totalHoldingCost > 0 ? pnl / store.totalHoldingCost * 100 : 0
                    HStack(spacing: 4) {
                        Text(pnl >= 0 ? "+¥\(Int(pnl))" : "-¥\(Int(abs(pnl)))")
                        Text("(\(String(format: "%+.2f", pnlPct))%)")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(pnl >= 0 ? .green : .red)
                }
            }

            if let updated = priceService.lastUpdated {
                HStack {
                    Image(systemName: "wifi")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("行情更新 \(updated, style: .time)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }

    // MARK: - 各基金持仓卡片
    private var fundCardsSection: some View {
        VStack(spacing: 10) {
            ForEach(store.funds) { fund in
                FundHoldingCard(
                    fund: fund,
                    priceInfo: priceService.prices[fund.code]
                )
                .onTapGesture { editingHolding = fund }
            }
        }
    }

    // MARK: - 今日定投任务
    private var todayTaskSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日任务")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ForEach(todayFunds) { fund in
                if let record = store.record(for: fund, on: Date()) {
                    TodayTaskRow(fund: fund, record: record)
                        .onTapGesture { editingRecord = (fund, record) }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.07), radius: 6, x: 0, y: 2)
    }

    private var todayFunds: [Fund] { store.fundsForToday() }

    // binding helpers
    private var editingRecordBinding: Binding<FundRecordPair?> {
        Binding(
            get: { editingRecord.map { FundRecordPair(fund: $0.0, record: $0.1) } },
            set: { editingRecord = $0.map { ($0.fund, $0.record) } }
        )
    }
}

// MARK: - 基金持仓卡片
struct FundHoldingCard: View {
    let fund: Fund
    let priceInfo: PriceInfo?

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(fund.color)
                .frame(width: 4, height: 64)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(fund.name)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                    if let info = priceInfo, info.isHighPosition {
                        Text("高位")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.15))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                    }
                }
                Text(fund.code)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // 实时价格行
                if let info = priceInfo {
                    HStack(spacing: 6) {
                        Text(String(format: "%.4f", info.estimatedNAV))
                            .font(.caption.monospacedDigit())
                        changeTag(info.changePercent)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                if fund.isETF {
                    Text("\(fund.holdingLots) 手")
                        .font(.subheadline.bold())
                    if let info = priceInfo, fund.averageCost > 0 {
                        let pnlPct = (info.estimatedNAV - fund.averageCost) / fund.averageCost * 100
                        Text(String(format: "%+.2f%%", pnlPct))
                            .font(.caption.bold())
                            .foregroundColor(pnlPct >= 0 ? .green : .red)
                    }
                } else {
                    Text("¥\(Int(fund.holdingValue))")
                        .font(.subheadline.bold())
                    if fund.holdingCost > 0 {
                        let pnl = (fund.holdingValue - fund.holdingCost) / fund.holdingCost * 100
                        Text(String(format: "%+.2f%%", pnl))
                            .font(.caption.bold())
                            .foregroundColor(pnl >= 0 ? .green : .red)
                    }
                }
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    @ViewBuilder
    private func changeTag(_ pct: Double) -> some View {
        Text(String(format: "%+.2f%%", pct))
            .font(.caption2.monospacedDigit())
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(pct >= 0 ? Color.green.opacity(0.12) : Color.red.opacity(0.12))
            .foregroundColor(pct >= 0 ? .green : .red)
            .cornerRadius(4)
    }
}

// MARK: - 今日任务行
struct TodayTaskRow: View {
    let fund: Fund
    let record: InvestmentRecord

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(fund.color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(fund.name).font(.subheadline)
                Text(fund.actionText).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: record.status.icon)
                Text(record.status.rawValue)
                    .font(.caption)
            }
            .foregroundColor(record.status.color)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }
}
