import SwiftUI
import UserNotifications
import UIKit

enum BrewKind: String, Codable {
    case steep
    case simmer
}

struct Tea: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let kind: BrewKind
    let waterC: Int
    let baseSeconds: Int
    let extraSeconds: Int
    let rinseSeconds: Int?
    let typicalInfusions: Int
    let note: String

    var reSteeps: Bool { typicalInfusions > 1 }
}

extension Tea {
    static let all: [Tea] = [
        Tea(
            id: "chai",
            name: "Chai",
            kind: .simmer,
            waterC: 100,
            baseSeconds: 10 * 60,
            extraSeconds: 0,
            rinseSeconds: nil,
            typicalInfusions: 1,
            note: "Milk and masala. Keep a rolling simmer."
        ),
        Tea(
            id: "black",
            name: "Black",
            kind: .steep,
            waterC: 100,
            baseSeconds: 4 * 60,
            extraSeconds: 45,
            rinseSeconds: nil,
            typicalInfusions: 2,
            note: "Full boil. Second cup can go a bit longer."
        ),
        Tea(
            id: "green",
            name: "Green",
            kind: .steep,
            waterC: 75,
            baseSeconds: 150,
            extraSeconds: 30,
            rinseSeconds: nil,
            typicalInfusions: 2,
            note: "Don't use boiling water — it turns bitter."
        ),
        Tea(
            id: "oolong",
            name: "Oolong",
            kind: .steep,
            waterC: 90,
            baseSeconds: 2 * 60,
            extraSeconds: 20,
            rinseSeconds: nil,
            typicalInfusions: 5,
            note: "This leaf wants several short steeps."
        ),
        Tea(
            id: "white",
            name: "White",
            kind: .steep,
            waterC: 80,
            baseSeconds: 4 * 60,
            extraSeconds: 30,
            rinseSeconds: nil,
            typicalInfusions: 2,
            note: "Cooler water, unhurried steep."
        ),
        Tea(
            id: "puerh",
            name: "Pu-erh",
            kind: .steep,
            waterC: 100,
            baseSeconds: 3 * 60,
            extraSeconds: 15,
            rinseSeconds: 10,
            typicalInfusions: 6,
            note: "Rinse the leaf first, then many short steeps."
        ),
        Tea(
            id: "herbal",
            name: "Herbal",
            kind: .steep,
            waterC: 100,
            baseSeconds: 6 * 60,
            extraSeconds: 0,
            rinseSeconds: nil,
            typicalInfusions: 1,
            note: "Usually one long steep. Cover the cup."
        ),
    ]

    static let fallback = all[1]
}

enum Phase: Equatable {
    case idle
    case running
    case paused
    case done
}

@MainActor
final class SteepEngine: ObservableObject {
    @Published private(set) var tea: Tea
    @Published private(set) var infusion: Int
    @Published private(set) var isRinse: Bool
    @Published private(set) var phase: Phase
    @Published private(set) var planned: TimeInterval
    @Published private(set) var total: TimeInterval

    private var endDate: Date?
    private var didWarn = false
    private var didCheckIn = false

    private static let lastTeaKey = "lastTeaId"
    private static let notifID = "chaicheck.steep.done"

    init() {
        let savedId = UserDefaults.standard.string(forKey: Self.lastTeaKey)
        let tea = Tea.all.first(where: { $0.id == savedId }) ?? Tea.fallback
        self.tea = tea
        self.infusion = 1
        self.isRinse = tea.rinseSeconds != nil
        let start = Self.defaultDuration(tea: tea, infusion: 1, rinse: tea.rinseSeconds != nil)
        self.planned = start
        self.total = start
        self.phase = .idle
    }

    var isActive: Bool { phase == .running || phase == .paused }

    func remaining(at now: Date = .now) -> TimeInterval {
        switch phase {
        case .idle, .paused:
            return planned
        case .running:
            guard let endDate else { return planned }
            return max(0, endDate.timeIntervalSince(now))
        case .done:
            return 0
        }
    }

    func progress(at now: Date = .now) -> Double {
        guard total > 0 else { return 0 }
        switch phase {
        case .idle, .paused:
            return 0
        case .running:
            return min(1, max(0, 1 - remaining(at: now) / total))
        case .done:
            return 1
        }
    }

    var subtitle: String {
        if isRinse { return "Rinse — discard this water" }
        if tea.kind == .simmer { return "Simmer" }
        if tea.reSteeps {
            return "Infusion \(infusion) of ~\(tea.typicalInfusions)"
        }
        return "Steep"
    }

    var waterLine: String {
        if isRinse { return "Hot rinse · 10s" }
        return "\(tea.waterC)°C water"
    }

    var nextLine: String? {
        guard !isRinse, tea.reSteeps, tea.extraSeconds > 0 else { return nil }
        let extra = formatted(TimeInterval(tea.extraSeconds))
        return "Next steep +\(extra)"
    }

    var primaryTitle: String {
        switch phase {
        case .idle:
            if isRinse { return "Rinse" }
            return tea.kind == .simmer ? "Simmer" : "Steep"
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        case .done:
            if isRinse { return "Steep" }
            if tea.kind == .simmer { return "Another pot" }
            return "Steep again"
        }
    }

    func formatted(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(ceil(interval - 0.0001)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    func select(_ tea: Tea) {
        guard phase != .running else { return }
        cancelNotification()
        self.tea = tea
        UserDefaults.standard.set(tea.id, forKey: Self.lastTeaKey)
        infusion = 1
        isRinse = tea.rinseSeconds != nil
        planned = Self.defaultDuration(tea: tea, infusion: 1, rinse: isRinse)
        total = planned
        phase = .idle
        endDate = nil
        didWarn = false
        didCheckIn = false
        updateIdleTimer()
        Haptics.tap()
    }

    func start() {
        let duration = remaining(at: .now)
        guard duration > 0 else { return }
        requestNotificationsIfNeeded()
        endDate = Date().addingTimeInterval(duration)
        total = duration
        phase = .running
        didWarn = duration <= 10
        didCheckIn = tea.kind != .simmer || duration <= 120
        scheduleNotification(in: duration)
        updateIdleTimer()
    }

    func pause() {
        guard phase == .running else { return }
        planned = remaining(at: .now)
        phase = .paused
        endDate = nil
        cancelNotification()
        updateIdleTimer()
    }

    func resume() {
        guard phase == .paused else { return }
        start()
    }

    func cancel() {
        cancelNotification()
        phase = .idle
        planned = Self.defaultDuration(tea: tea, infusion: infusion, rinse: isRinse)
        total = planned
        endDate = nil
        didWarn = false
        didCheckIn = false
        updateIdleTimer()
    }

    func advance() {
        guard phase == .done else { return }
        if isRinse {
            isRinse = false
            infusion = 1
            planned = TimeInterval(tea.baseSeconds)
            total = planned
            phase = .idle
            return
        }
        if tea.kind == .simmer || !tea.reSteeps {
            reset()
            return
        }
        infusion += 1
        planned = TimeInterval(tea.baseSeconds + (infusion - 1) * tea.extraSeconds)
        total = planned
        phase = .idle
        didWarn = false
        didCheckIn = false
    }

    func reset() {
        cancelNotification()
        infusion = 1
        isRinse = tea.rinseSeconds != nil
        planned = Self.defaultDuration(tea: tea, infusion: 1, rinse: isRinse)
        total = planned
        phase = .idle
        endDate = nil
        didWarn = false
        didCheckIn = false
        updateIdleTimer()
    }

    func nudge(_ delta: TimeInterval) {
        switch phase {
        case .done:
            return
        case .idle, .paused:
            planned = max(15, planned + delta)
            total = planned
        case .running:
            guard let endDate else { return }
            let next = max(Date().addingTimeInterval(15), endDate.addingTimeInterval(delta))
            self.endDate = next
            let remaining = next.timeIntervalSinceNow
            total = max(15, total + delta)
            didWarn = remaining <= 10
            scheduleNotification(in: remaining)
        }
        Haptics.tap()
    }

    func tick(at now: Date) {
        guard phase == .running, let endDate else { return }
        let left = endDate.timeIntervalSince(now)
        if tea.kind == .simmer, !didCheckIn, left <= 120, left > 10 {
            didCheckIn = true
            Haptics.checkIn()
        }
        if !didWarn, left <= 10, left > 0 {
            didWarn = true
            Haptics.warn()
        }
        if left <= 0 {
            complete()
        }
    }

    private func complete() {
        guard phase == .running else { return }
        phase = .done
        endDate = nil
        cancelNotification()
        updateIdleTimer()
        Haptics.done()
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = (phase == .running)
    }

    private static func defaultDuration(tea: Tea, infusion: Int, rinse: Bool) -> TimeInterval {
        if rinse, let rinseSeconds = tea.rinseSeconds {
            return TimeInterval(rinseSeconds)
        }
        return TimeInterval(tea.baseSeconds + max(0, infusion - 1) * tea.extraSeconds)
    }

    private func requestNotificationsIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(in interval: TimeInterval) {
        cancelNotification()
        guard interval > 0.5 else { return }
        let content = UNMutableNotificationContent()
        if isRinse {
            content.title = "Rinse is done"
            content.body = "Dump the water, then steep \(tea.name)."
        } else if tea.kind == .simmer {
            content.title = "Chai is ready"
            content.body = "Take it off the heat."
        } else {
            content.title = "Tea is ready"
            content.body = tea.reSteeps ? "\(tea.name) · infusion \(infusion)" : tea.name
        }
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notifID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notifID])
    }
}

enum Haptics {
    static func tap() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func warn() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    static func checkIn() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    static func done() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

enum Theme {
    static let bg = Color(red: 0.102, green: 0.071, blue: 0.047)
    static let cream = Color(red: 0.953, green: 0.902, blue: 0.816)
    static let amber = Color(red: 0.910, green: 0.639, blue: 0.353)
    static let muted = Color(red: 0.541, green: 0.451, blue: 0.376)
    static let line = Color(red: 0.275, green: 0.196, blue: 0.149)
    static let chip = Color(red: 0.165, green: 0.114, blue: 0.082)
}
