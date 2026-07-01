import SwiftUI

struct EditRecordView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss

    let fund: Fund
    var existingRecord: InvestmentRecord?

    @State private var date         = Date()
    @State private var actualAmount = ""
    @State private var units        = ""
    @State private var price        = ""
    @State private var status       = RecordStatus.success
    @State private var note         = ""

    var isEditing: Bool { existingRecord != nil }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 4).fill(fund.color).frame(width: 4, height: 44)
                        VStack(alignment: .leading, spacing: 2) {
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
                    .pickerStyle(.menu)
                }

                if status != .skipped && status != .failed {
                    Section("金额详情") {
                        HStack {
                            Text("实际金额")
                            Spacer()
                            TextField(fund.isETF ? "0" : "\(Int(fund.dcaAmount))", text: $actualAmount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                            Text("元")
                        }
                        if fund.isETF {
                            HStack {
                                Text("成交价")
                                Spacer()
                                TextField("元/股", text: $price)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                Text("元")
                            }
                            HStack {
                                Text("成交手数")
                                Spacer()
                                TextField("手", text: $units)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                Text("手")
                            }
                        } else {
                            HStack {
                                Text("确认净值")
                                Spacer()
                                TextField("可选", text: $price)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                            }
                        }
                    }
                }

                Section("备注") {
                    ZStack(alignment: .topLeading) {
                        if note.isEmpty {
                            Text("余额不足 / 延迟执行 / 其他")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $note)
                            .frame(minHeight: 60)
                    }
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
            .navigationTitle(isEditing ? "编辑记录" : "确认执行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear { prefill() }
        }
    }

    private func prefill() {
        guard let r = existingRecord else {
            if !fund.isETF { actualAmount = "\(Int(fund.dcaAmount))" }
            return
        }
        date         = r.date
        actualAmount = r.actualAmount > 0 ? "\(Int(r.actualAmount))" : ""
        units        = r.units.map  { String(format: "%.2f", $0) } ?? ""
        price        = r.price.map  { String(format: "%.4f", $0) } ?? ""
        status       = r.status == .pending ? .success : r.status
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
        record.date         = date
        record.actualAmount = amt
        record.units        = u
        record.price        = p
        record.status       = status
        record.note         = note.isEmpty ? nil : note
        record.isAutoGenerated = false

        if isEditing {
            store.updateRecord(record)
        } else {
            store.addRecord(record)
        }
        dismiss()
    }
}
