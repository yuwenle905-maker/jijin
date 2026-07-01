import SwiftUI

// MARK: - 新增/编辑投资记录
struct EditRecordView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    let fund: Fund
    var existingRecord: InvestmentRecord?

    @State private var date          = Date()
    @State private var actualAmount  = ""
    @State private var units         = ""
    @State private var price         = ""
    @State private var status        = RecordStatus.success
    @State private var note          = ""

    var isEditing: Bool { existingRecord != nil }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fund.color)
                            .frame(width: 4, height: 40)
                        VStack(alignment: .leading) {
                            Text(fund.name).font(.headline)
                            Text(fund.actionText).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                Section("执行日期") {
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }

                Section("执行结果") {
                    Picker("状态", selection: $status) {
                        ForEach(RecordStatus.allCases, id: \.self) { s in
                            Label(s.rawValue, systemImage: s.icon).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("金额详情") {
                    HStack {
                        Text("实际金额")
                        Spacer()
                        TextField(fund.isETF ? "0" : "\(Int(fund.dcaAmount))", text: $actualAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("元")
                    }
                    if fund.isETF {
                        HStack {
                            Text("成交价")
                            Spacer()
                            TextField("元/股", text: $price)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("元")
                        }
                        HStack {
                            Text("成交手数")
                            Spacer()
                            TextField("手", text: $units)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("手")
                        }
                    } else {
                        HStack {
                            Text("确认净值")
                            Spacer()
                            TextField("可选", text: $price)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("确认份数")
                            Spacer()
                            TextField("可选", text: $units)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section("备注") {
                    TextField("余额不足 / 延迟执行 / 其他", text: $note, axis: .vertical)
                        .lineLimit(3)
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            if let r = existingRecord { store.deleteRecord(id: r.id) }
                            dismiss()
                        } label: {
                            Label("删除此记录", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑记录" : "记录执行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { prefill() }
        }
    }

    private var canSave: Bool {
        status == .failed || status == .skipped || !actualAmount.isEmpty
    }

    private func prefill() {
        guard let r = existingRecord else {
            // 新增时预填计划金额
            if !fund.isETF { actualAmount = "\(Int(fund.dcaAmount))" }
            return
        }
        date         = r.date
        actualAmount = r.actualAmount > 0 ? "\(Int(r.actualAmount))" : ""
        units        = r.units.map { "\($0)" } ?? ""
        price        = r.price.map { "\($0)" } ?? ""
        status       = r.status
        note         = r.note ?? ""
    }

    private func save() {
        let amt  = Double(actualAmount) ?? 0
        let u    = Double(units)
        let p    = Double(price)

        var record = existingRecord ?? InvestmentRecord(
            fundID: fund.id,
            date: date,
            plannedAmount: fund.isETF ? 0 : fund.dcaAmount,
            actualAmount: amt,
            status: status
        )
        record.date          = date
        record.actualAmount  = amt
        record.units         = u
        record.price         = p
        record.status        = status
        record.note          = note.isEmpty ? nil : note

        if isEditing {
            store.updateRecord(record)
        } else {
            store.addRecord(record)
        }
        dismiss()
    }
}
