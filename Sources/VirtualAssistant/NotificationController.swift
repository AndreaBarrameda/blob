import Foundation
import UserNotifications
import AppKit

class NotificationController {
    private var scheduledTimers: [String: Timer] = [:]

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error)")
            }
        }
    }

    func sendNotification(title: String, body: String, delay: TimeInterval = 0) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send notification: \(error)")
            } else {
                print("📬 Notification: \(title) → \(body)")
            }
        }
    }

    func remind(message: String, after seconds: TimeInterval) {
        let delayMinutes = Int(seconds / 60)
        let delaySeconds = Int(seconds) % 60
        let timeStr = delayMinutes > 0 ? "\(delayMinutes)m\(delaySeconds > 0 ? "\(delaySeconds)s" : "")" : "\(delaySeconds)s"
        let title = "Reminder in \(timeStr)"
        sendNotification(title: title, body: message, delay: seconds)
    }

    func remindAt(message: String, hour: Int, minute: Int) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        components.hour = hour
        components.minute = minute

        var fireDate: Date?

        if let todayDate = calendar.date(from: components), todayDate > Date() {
            fireDate = todayDate
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) {
            var tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
            tomorrowComponents.hour = hour
            tomorrowComponents.minute = minute
            fireDate = calendar.date(from: tomorrowComponents)
        }

        if let fireDate = fireDate {
            let delay = fireDate.timeIntervalSince(Date())
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let timeStr = formatter.string(from: fireDate)
            let title = "Reminder at \(timeStr)"
            sendNotification(title: title, body: message, delay: delay)
        }
    }

    func listScheduledNotifications(completion: @escaping ([String]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let notifications = requests.map { "\($0.content.title): \($0.content.body)" }
            completion(notifications)
        }
    }

    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ All notifications cleared")
    }
}
