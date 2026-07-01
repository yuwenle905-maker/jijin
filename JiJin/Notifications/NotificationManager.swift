import UserNotifications
import Foundation

enum NotificationManager {

    // MARK: 请求权限
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: 重新注册所有定投提醒（每次启动调用）
    static func scheduleAll(funds: [Fund]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        for fund in funds {
            for day in fund.scheduleDays {
                if fund.isETF, let time = fund.etfTime {
                    scheduleETFReminder(fund: fund, weekday: day, timeString: time)
                } else {
                    scheduleDCAReminder(fund: fund, weekday: day)
                }
            }
        }

        // 每年12月1日再平衡提醒
        scheduleRebalanceReminder()
    }

    // MARK: 场内ETF提醒（精确到时间）
    private static func scheduleETFReminder(fund: Fund, weekday: Int, timeString: String) {
        let parts = timeString.split(separator: ":").map { Int($0) ?? 0 }
        guard parts.count == 2 else { return }

        var comps = DateComponents()
        comps.weekday = isoToSwiftWeekday(weekday)
        comps.hour   = parts[0]
        comps.minute = parts[1]

        let content = UNMutableNotificationContent()
        content.title = "📈 \(fund.name)"
        content.body  = "现在 \(timeString)，记得 \(fund.actionText)"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: "etf_\(fund.id)_\(weekday)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: 定投提醒（早上9点）
    private static func scheduleDCAReminder(fund: Fund, weekday: Int) {
        var comps = DateComponents()
        comps.weekday = isoToSwiftWeekday(weekday)
        comps.hour   = 9
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "💰 定投提醒"
        content.body  = "\(fund.name) 今天定投 \(Int(fund.dcaAmount)) 元"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: "dca_\(fund.id)_\(weekday)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // MARK: 年度再平衡提醒（每年12月1日上午9点）
    private static func scheduleRebalanceReminder() {
        var comps = DateComponents()
        comps.month  = 12
        comps.day    = 1
        comps.hour   = 9
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "⚖️ 年度再平衡"
        content.body  = "12月到了，打开定投管家检查各资产占比，执行年度再平衡。"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: "rebalance_annual", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    // ISO weekday (1=Mon) → Swift weekday (1=Sun,2=Mon)
    private static func isoToSwiftWeekday(_ iso: Int) -> Int {
        iso == 7 ? 1 : iso + 1
    }
}
