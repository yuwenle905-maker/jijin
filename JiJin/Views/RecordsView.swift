import SwiftUI

// MARK: - 定投记录列表
struct RecordsView: View {
    @EnvironmentObject var store: DataStore
    @State private var editingRecord: (Fund, InvestmentRecord)? = nil

    var body: some View {
        NavigationView {
            Group {
                if store.records.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }
            .navigationTitle("定投记录")
            .sheet(item: editingBinding) { pair in
                EditRecordView(fund: pair.fund, existingRecord: pair.record)
                    .environmentObject(store)
            }
        }
    }

    // MARK: 空态
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无记录")
                .foregroundColor(.secondary)
            Text("在「今日任务」完成操作后记录执行情况")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: 记录列表（按日期分组）
    private var recordsList: some View {
        List {
            ForEach(store.recordsByDate, id: \.0) { day, dayRecords in
                Section(header: Text(day, style: .date)) {
                    ForEach(dayRecords) { record in
                        if let fund = store.fund(for: record.fundID) {
                            RecordRow(fund: fund, record: record)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingRecord = (fund, record)
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // Sheet binding helpers
    private var editingBinding: Binding<FundRecordPair?> {
        Binding(
            get: { editingRecord.map { FundRecordPair(fund: $0.0, record: $0.1) } },
            set: { editingRecord = $0.map { ($0.fund, $0.record) } }
        )
    }
}

// Identifiable wrapper for sheet
struct FundRecordPair: Identifiable {
    let id = UUID()
    let fund: Fund
    let record: InvestmentRecord
}

// MARK: - 单条记录行
struct RecordRow: View {
    let fund: Fund
    let record: InvestmentRecord

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(fund.color)
                .frame(width: 3, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(fund.name)
                    .font(.subheadline.bold())
                if record.actualAmount > 0 {
                    Text("¥\(Int(record.actualAmount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let note = record.note {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: record.status.icon)
                    .foregroundColor(record.status.color)
                Text(record.status.rawValue)
                    .font(.caption2)
                    .foregroundColor(record.status.color)
            }
        }
    }
}
