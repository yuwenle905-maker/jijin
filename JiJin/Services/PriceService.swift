import Foundation

struct PriceInfo {
    let code: String
    let estimatedNAV: Double    // 当前价/估算净值
    let yesterdayNAV: Double    // 昨日收盘/净值
    let changePercent: Double   // 涨跌幅 %
    let updateTime: String
    var isHighPosition: Bool { changePercent > 1.5 }
}

// 天天基金 JSONP 结构（场外基金）
private struct FundGz: Decodable {
    let dwjz: String    // 昨日净值
    let gsz: String     // 今日估算净值
    let gszzl: String   // 涨跌幅
    let gztime: String
}

class PriceService: ObservableObject {
    @Published var prices: [String: PriceInfo] = [:]
    @Published var isLoading = false
    @Published var lastUpdated: Date? = nil

    // 上交所ETF代码前缀（5或6开头）
    private func isSH(_ code: String) -> Bool {
        code.hasPrefix("5") || code.hasPrefix("6")
    }

    func fetchAll(codes: [String]) {
        isLoading = true
        Task {
            await withTaskGroup(of: (String, PriceInfo?).self) { group in
                for code in codes {
                    group.addTask { [weak self] in
                        guard let self else { return (code, nil) }
                        // 场内ETF用新浪实时接口，场外用天天基金估值
                        let info = await (self.isExchangeETF(code)
                            ? self.fetchSinaPrice(code: code)
                            : self.fetchFundGz(code: code))
                        return (code, info)
                    }
                }
                var result: [String: PriceInfo] = [:]
                for await (code, info) in group {
                    if let info { result[code] = info }
                }
                await MainActor.run {
                    self.prices = result
                    self.isLoading = false
                    self.lastUpdated = Date()
                }
            }
        }
    }

    // 513500 这类场内交易ETF
    // 注意：513500 虽然叫"联接"但实际上是场内基金代码，走新浪行情
    private func isExchangeETF(_ code: String) -> Bool {
        // 6位数字，5或6开头，且代码在常见ETF范围
        let etfCodes = ["513500", "513100", "510300", "510500"]
        return etfCodes.contains(code)
    }

    // 新浪财经实时行情（场内ETF）
    private func fetchSinaPrice(code: String) async -> PriceInfo? {
        let exchange = isSH(code) ? "sh" : "sz"
        guard let url = URL(string: "https://hq.sinajs.cn/list=\(exchange)\(code)") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")

        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }

        // 新浪返回 GBK，价格字段是 ASCII 可以直接用 latin1
        let raw = String(data: data, encoding: .isoLatin1)
                  ?? String(data: data, encoding: .utf8)
                  ?? ""

        // 格式: var hq_str_sh513500="名称,开,昨收,现价,高,低,买一,卖一,...,日期,时间"
        guard let s = raw.firstIndex(of: "\""),
              let e = raw.lastIndex(of: "\""),
              s < e else { return nil }
        let fields = String(raw[raw.index(after: s)..<e]).components(separatedBy: ",")
        guard fields.count > 3 else { return nil }

        let current   = Double(fields[3]) ?? 0
        let prevClose = Double(fields[2]) ?? 0
        let chgPct    = prevClose > 0 ? (current - prevClose) / prevClose * 100 : 0
        let time      = fields.count > 31 ? "\(fields[30]) \(fields[31])" : ""

        return PriceInfo(code: code, estimatedNAV: current, yesterdayNAV: prevClose,
                         changePercent: chgPct, updateTime: time)
    }

    // 天天基金估值（场外基金）
    private func fetchFundGz(code: String) async -> PriceInfo? {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let url = URL(string: "https://fundgz.1234567.com.cn/js/\(code).js?rt=\(ts)") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("https://fund.eastmoney.com", forHTTPHeaderField: "Referer")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let raw = String(data: data, encoding: .utf8),
              let s = raw.firstIndex(of: "{"),
              let e = raw.lastIndex(of: "}") else { return nil }

        guard let gz = try? JSONDecoder().decode(FundGz.self,
                        from: Data(String(raw[s...e]).utf8)) else { return nil }

        let est  = Double(gz.gsz)    ?? 0
        let prev = Double(gz.dwjz)   ?? 0
        let chg  = Double(gz.gszzl)  ?? 0

        return PriceInfo(code: code, estimatedNAV: est, yesterdayNAV: prev,
                         changePercent: chg, updateTime: gz.gztime)
    }
}
