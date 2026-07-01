import SwiftUI

// MARK: - 今日任务主视图
struct TodayView: View {
    @EnvironmentObject var store: DataStore
    @State private var now = Date()
    @State private var addingRecord: Fund? = nil
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    dateHeader
                    if todayFunds.isEmpty {
                        restCard
                    } else {
                        ForEach(todayFunds) { fund in
                            FundTaskCard(fund: fund, record: store.record(for: fund, on: now)) {
                                addingRecord = fund
                            }
                        }
                    }
                    weekAheadSection
                }
                .padding()
            }
            .navigationTitle("今日任务")
            .onReceive(timer) { t in now = t }
            .sheet(item: $addingRecord) { fund in
                EditRecordView(fund: fund, existingRecord: store.record(for: fund, on: now))
                    .environmentObject(store)
            }
        }
    }

    private var todayFunds: [Fund] { store.fundsForToday() }

    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(now, style: .date)
                    .font(.headline)
                Text(weekdayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            // 本周合计定投金额
            VStack(alignment: .trailing, spacing: 2) {
                Text("本周计划")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("¥\(Int(weeklyPlanned))")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    private var restCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("今天没有定投任务")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var weekAheadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本周安排")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            ForEach(1...5, id: \.self) { day in
                let dayFunds = store.funds.filter { $0.scheduleDays.contains(day) }
                if !dayFunds.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Text(["", "周一", "周二", "周三", "周四", "周五"][day])
                            .font(.caption.bold())
                            .frame(width: 32, alignment: .leading)
                            .foregroundColor(day == currentISOWeekday ? .blue : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(dayFunds) { f in
                                Text("• \(f.name)  \(f.actionText)")
                                    .font(.caption)
                                    .foregroundColor(day == currentISOWeekday ? .primary : .secondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var weekdayName: String {
        ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"][currentISOWeekday]
    }

    private var currentISOWeekday: Int {
        let w = Calendar.current.component(.weekday, from: now)
        return w == 1 ? 7 : w - 1
    }

    private var weeklyPlanned: Double {
        store.funds.reduce(0) { $0 + $1.dcaAmount }
    }
}

// MARK: - 单个基金任务卡片
struct FundTaskCard: View {
    let fund: Fund
    let record: InvestmentRecord?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 颜色标识
                RoundedRectangle(cornerRadius: 4)
                    .fill(fund.color)
                    .frame(width: 4)
                    .frame(height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(fund.name)
                            .font(.subheadline.bold())
                        Spacer()
                        if fund.isETF, let time = fund.etfTime {
                            ETFCountdown(targetTime: time)
                        }
                    }
                    Text(fund.code)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(fund.actionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 完成状态
                if let r = record {
                    Image(systemName: r.status.icon)
                        .foregroundColor(r.status.color)
                        .font(.title3)
                } else {
                    Image(systemName: "chevron.right.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ETF倒计时标签（仅周一显示）
struct ETFCountdown: View {
    let targetTime: String
    @State private var remaining: String = ""
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(remaining.isEmpty ? targetTime : remaining)
            .font(.caption2.monospacedDigit())
            .foregroundColor(remaining.isEmpty ? .secondary : .orange)
            .onAppear { update() }
            .onReceive(timer) { _ in update() }
    }

    private func update() {
        let parts = targetTime.split(separator: ":").map { Int($0) ?? 0 }
        guard parts.count == 2 else { return }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour   = parts[0]
        comps.minute = parts[1]
        comps.second = 0
        guard let target = Calendar.current.date(from: comps) else { return }
        let diff = Int(target.timeIntervalSince(Date()))
        if diff > 0 && diff < 3600 {
            remaining = "还有 \(diff / 60) 分钟"
        } else {
            remaining = ""
        }
    }
}
