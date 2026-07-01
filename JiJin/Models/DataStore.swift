import Foundation
import Combine

// MARK: - DataStore
class DataStore: ObservableObject {

    @Published var funds:   [Fund]              = []
    @Published var records: [InvestmentRecord]  = []

    private static let fundsURL   = docURL("funds_v1.json")
    private static let recordsURL = docURL("records_v1.json")

    init() {
        load()
        if funds.isEmpty { seedDefaultFunds() }
    }

    // MARK: 持久化
    func load() {
        funds   = decode([Fund].self,             from: DataStore.fundsURL)   ?? []
        records = decode([InvestmentRecord].self, from: DataStore.recordsURL) ?? []
    }

    func save() {
        encode(funds,   to: DataStore.fundsURL)
        encode(records, to: DataStore.recordsURL)
    }

    // MARK: 记录增删改
    func addRecord(_ r: InvestmentRecord) {
        records.append(r)
        save()
    }

    func updateRecord(_ r: InvestmentRecord) {
        if let i = records.firstIndex(where: { $0.id == r.id }) {
            records[i] = r
            save()
        }
    }

    func deleteRecord(id: UUID) {
        records.removeAll { $0.id == id }
        save()
    }

    // MARK: 基金配置更新
    func updateFund(_ f: Fund) {
        if let i = funds.firstIndex(where: { $0.id == f.id }) {
            funds[i] = f
            save()
        }
    }

    // MARK: 今日应操作的基金
    func fundsForToday() -> [Fund] {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Swift weekday: 1=Sun,2=Mon,...,7=Sat  →  转成 1=Mon...7=Sun
        let day = (weekday == 1) ? 7 : weekday - 1
        return funds.filter { $0.scheduleDays.contains(day) }
    }

    // MARK: 某天某基金是否已有记录
    func record(for fund: Fund, on date: Date) -> InvestmentRecord? {
        let cal = Calendar.current
        return records.first {
            $0.fundID == fund.id &&
            cal.isDate($0.date, inSameDayAs: date)
        }
    }

    // MARK: 按日期分组记录（降序）
    var recordsByDate: [(Date, [InvestmentRecord])] {
        let cal = Calendar.current
        var dict: [Date: [InvestmentRecord]] = [:]
        for r in records {
            let day = cal.startOfDay(for: r.date)
            dict[day, default: []].append(r)
        }
        return dict.sorted { $0.key > $1.key }
    }

    // MARK: 基金名查找
    func fund(for id: UUID) -> Fund? {
        funds.first { $0.id == id }
    }

    // MARK: 预填种子数据
    private func seedDefaultFunds() {
        funds = [
            Fund(
                name: "标普500ETF联接",
                code: "513500",
                colorHex: "FF2C6FED",
                scheduleDays: [1],         // 周一
                dcaAmount: 0,
                isETF: true,
                etfTime: "14:50",
                etfLots: 100,
                targetMinPct: 0.20,
                targetMaxPct: 0.30
            ),
            Fund(
                name: "天弘中证红利低波100A",
                code: "008114",
                colorHex: "FFFF6B35",
                scheduleDays: [2],         // 周二
                dcaAmount: 250,
                isETF: false,
                targetMinPct: 0.18,
                targetMaxPct: 0.28
            ),
            Fund(
                name: "易方达增强回报债券A",
                code: "110017",
                colorHex: "FF34C759",
                scheduleDays: [2],         // 周二
                dcaAmount: 300,
                isETF: false,
                targetMinPct: nil,
                targetMaxPct: nil,
                isRebalanceTarget: false
            ),
            Fund(
                name: "华安黄金ETF联接A",
                code: "000216",
                colorHex: "FFFFCC00",
                scheduleDays: [2],         // 周二
                dcaAmount: 100,
                isETF: false,
                targetMinPct: nil,
                targetMaxPct: nil,
                isRebalanceTarget: false
            ),
            Fund(
                name: "易方达中证A500ETF联接A",
                code: "022459",
                colorHex: "FFAF52DE",
                scheduleDays: [4],         // 周四
                dcaAmount: 200,
                isETF: false,
                targetMinPct: 0.13,
                targetMaxPct: 0.22
            ),
        ]
        save()
    }

    // MARK: Codable 辅助
    private static func docURL(_ name: String) -> URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
    }

    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try? d.decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, to url: URL) {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        guard let data = try? e.encode(value) else { return }
        try? data.write(to: url, options: .atomicWrite)
    }
}
