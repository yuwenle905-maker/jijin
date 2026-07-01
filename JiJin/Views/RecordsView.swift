import SwiftUI

// 记录Tab：改为引导用户点击首页基金卡片查看详情
struct RecordsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var priceService: PriceService

    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("点击首页各基金卡片，可查看该基金的定投记录（按月分组）")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }

                Section("快速跳转") {
                    ForEach(store.funds) { fund in
                        NavigationLink(destination:
                            FundDetailView(fund: fund)
                                .environmentObject(store)
                                .environmentObject(priceService)
                        ) {
                            HStack(spacing: 10) {
                                Circle().fill(fund.color).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(fund.name).font(.subheadline.bold())
                                    let count = store.records(for: fund)
                                        .filter { $0.status != .pending }.count
                                    Text("共 \(count) 条记录  · \(fund.scheduleText)")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("定投记录")
        }
    }
}
