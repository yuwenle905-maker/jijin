import Foundation

// MARK: - 实时价格数据
struct PriceInfo {
    let code: String
    let estimatedNAV: Double    // 今日估算净值/价格
    let yesterdayNAV: Double    // 昨日净值
    let changePercent: Double   // 涨跌幅 %
    let updateTime: String
    let isHighPosition: Bool    // 是否相对高位（近一年估值分位）
    let positionPct: Double?    // 估值分位（0~1，越高越贵）
}

// MARK: - 天天基金 JSONP 解析结构
private struct FundGzResponse: Decodable {
    let fundcode: String
    let dwjz: String    // 昨日净值
    let gsz: String     // 今日估算净值
    let gszzl: String   // 涨跌幅 %
    let gztime: String
}

// MARK: - PriceService
class PriceService: ObservableObject {
    @Published var prices: [String: PriceInfo] = [:]
    @Published var isLoading = false
    @Published var lastUpdated: Date? = nil

    // 天天基金估值接口（JSONP格式）
    private let baseURL = "https://fundgz.1234567.com.cn/js"

    func fetchAll(codes: [String]) {
        isLoading = true
        Task {
            await withTaskGroup(of: (String, PriceInfo?).self) { group in
                for code in codes {
                    group.addTask { [weak self] in
                        let info = await self?.fetchOne(code: code)
                        return (code, info)
                    }
                }
                var result: [String: PriceInfo] = [:]
                for await (code, info) in group {
                    if let info = info { result[code] = info }
                }
                await MainActor.run {
                    self.prices = result
                    self.isLoading = false
                    self.lastUpdated = Date()
                }
            }
        }
    }

    private func fetchOne(code: String) async -> PriceInfo? {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        guard let url = URL(string: "\(baseURL)/\(code).js?rt=\(ts)") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("https://fund.eastmoney.com", forHTTPHeaderField: "Referer")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let raw = String(data: data, encoding: .utf8) else { return nil }

        // 解析 JSONP: jsonpgz({...})
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}") else { return nil }
        let jsonStr = String(raw[start...end])
        guard let jsonData = jsonStr.data(using: .utf8),
              let gz = try? JSONDecoder().decode(FundGzResponse.self, from: jsonData) else { return nil }

        let est  = Double(gz.gsz)  ?? 0
        let prev = Double(gz.dwjz) ?? 0
        let chg  = Double(gz.gszzl) ?? 0

        // 简单高位判断：今日估值比昨日高超过1.5%，或涨幅连续为正（此处用涨跌幅>1.5%作为临时高位信号）
        let isHigh = chg > 1.5

        return PriceInfo(
            code: code,
            estimatedNAV: est,
            yesterdayNAV: prev,
            changePercent: chg,
            updateTime: gz.gztime,
            isHighPosition: isHigh,
            positionPct: nil
        )
    }
}
