import AVFoundation
import SwiftUI
import UIKit
import UserNotifications

struct SteepStep: Identifiable, Hashable, Codable {
    var id: UUID
    var seconds: Int
    var celsius: Int?
    var rung: String

    init(id: UUID = UUID(), seconds: Int, celsius: Int?, rung: String) {
        self.id = id
        self.seconds = seconds
        self.celsius = celsius
        self.rung = rung
    }
}

struct Tea: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var steps: [SteepStep]
    var note: String
    var presetKey: String?

    init(
        id: UUID = UUID(),
        name: String,
        steps: [SteepStep],
        note: String,
        presetKey: String? = nil
    ) {
        self.id = id
        self.name = name
        self.steps = steps
        self.note = note
        self.presetKey = presetKey
    }

    var summary: String {
        if steps.count == 1 {
            return TimeFormatting.clock(TimeInterval(steps[0].seconds))
        }
        return "\(steps.count) steeps"
    }

    var tempLine: String {
        let temps = steps.compactMap(\.celsius).map { "\($0)°" }
        guard temps.isEmpty == false else { return "" }
        return temps.joined(separator: "  ")
    }

    /// The one non-gray mark: liquor in the cup, not UI chrome.
    var liquor: Color { Liquor.color(for: presetKey) }
}

enum Liquor {
    static func color(for presetKey: String?) -> Color {
        switch presetKey {
        case "sencha":
            return Color(red: 0.20, green: 0.48, blue: 0.22) // chlorophyll
        case "matcha":
            return Color(red: 0.52, green: 0.72, blue: 0.28) // brighter powder green
        case "green":
            return Color(red: 0.38, green: 0.52, blue: 0.22) // olive liquor
        case "black":
            return Color(red: 0.28, green: 0.13, blue: 0.07) // dark brown
        case "chai":
            return Color(red: 0.55, green: 0.34, blue: 0.16) // milky brown
        case "oolong":
            return Color(red: 0.62, green: 0.42, blue: 0.18) // gold liquor
        case "white":
            return Color(red: 0.76, green: 0.68, blue: 0.48) // straw
        case "puerh":
            return Color(red: 0.36, green: 0.12, blue: 0.08) // deep burgundy-brown
        case "herbal":
            return Color(red: 0.62, green: 0.48, blue: 0.28) // dried flower
        default:
            return Color(red: 0.50, green: 0.50, blue: 0.50)
        }
    }
}

enum Ladder {
    static let multipliers: [(Double, String)] = [
        (1.0, "base"),
        (0.5, "×0.5"),
        (2.0, "×2"),
    ]

    static func steps(baseSeconds: Int, temps: [Int]) -> [SteepStep] {
        zip(multipliers, temps).map { multiplier, temp in
            let seconds = max(15, Int((Double(baseSeconds) * multiplier.0).rounded()))
            return SteepStep(seconds: seconds, celsius: temp, rung: multiplier.1)
        }
    }

    static func senchaStyle(
        name: String,
        baseSeconds: Int,
        temps: [Int] = [70, 80, 90],
        note: String,
        presetKey: String? = nil
    ) -> Tea {
        Tea(
            name: name,
            steps: steps(baseSeconds: baseSeconds, temps: temps),
            note: note,
            presetKey: presetKey
        )
    }
}

enum Preset {
    static let sencha = Ladder.senchaStyle(
        name: "Sencha",
        baseSeconds: 60,
        note: "1:00 / 0:30 / 2:00 · 70 / 80 / 90°C",
        presetKey: "sencha"
    )

    static let chai = Tea(
        name: "Chai",
        steps: [SteepStep(seconds: 10 * 60, celsius: 100, rung: "simmer")],
        note: "Milk and masala. Keep a rolling simmer.",
        presetKey: "chai"
    )

    static let black = Tea(
        name: "Black",
        steps: [
            SteepStep(seconds: 4 * 60, celsius: 100, rung: "base"),
            SteepStep(seconds: 4 * 60 + 45, celsius: 100, rung: "second"),
        ],
        note: "Full boil. Second cup a bit longer.",
        presetKey: "black"
    )

    static let green = Tea(
        name: "Green",
        steps: [
            SteepStep(seconds: 150, celsius: 75, rung: "base"),
            SteepStep(seconds: 180, celsius: 75, rung: "second"),
        ],
        note: "Western green. Don't use boiling water.",
        presetKey: "green"
    )

    static let oolong = Tea(
        name: "Oolong",
        steps: [
            SteepStep(seconds: 120, celsius: 90, rung: "1"),
            SteepStep(seconds: 140, celsius: 90, rung: "2"),
            SteepStep(seconds: 160, celsius: 90, rung: "3"),
            SteepStep(seconds: 180, celsius: 90, rung: "4"),
            SteepStep(seconds: 200, celsius: 90, rung: "5"),
        ],
        note: "Several short steeps.",
        presetKey: "oolong"
    )

    static let white = Tea(
        name: "White",
        steps: [
            SteepStep(seconds: 4 * 60, celsius: 80, rung: "base"),
            SteepStep(seconds: 4 * 60 + 30, celsius: 80, rung: "second"),
        ],
        note: "Cooler water, unhurried steep.",
        presetKey: "white"
    )

    static let puerh = Tea(
        name: "Pu-erh",
        steps: [
            SteepStep(seconds: 10, celsius: 100, rung: "rinse"),
            SteepStep(seconds: 3 * 60, celsius: 100, rung: "1"),
            SteepStep(seconds: 3 * 60 + 15, celsius: 100, rung: "2"),
            SteepStep(seconds: 3 * 60 + 30, celsius: 100, rung: "3"),
        ],
        note: "Rinse the leaf, then short steeps.",
        presetKey: "puerh"
    )

    static let herbal = Tea(
        name: "Herbal",
        steps: [SteepStep(seconds: 6 * 60, celsius: 100, rung: "steep")],
        note: "Usually one long steep. Cover the cup.",
        presetKey: "herbal"
    )

    static let all: [Tea] = [sencha, chai, black, green, oolong, white, puerh, herbal]
}

enum Phase: Equatable {
    case idle
    case running
    case ringing
}

@MainActor
final class TeaStore: ObservableObject {
    @Published var teas: [Tea] = []
    @Published var adding = false
    @Published var defaultID: UUID?

    private static let shelfKey = "shelf"
    private static let defaultKey = "defaultTeaId"

    var defaultTea: Tea? {
        if let defaultID, let match = teas.first(where: { $0.id == defaultID }) {
            return match
        }
        if teas.count == 1 {
            return teas[0]
        }
        return nil
    }

    func isDefault(_ tea: Tea) -> Bool {
        if defaultID == tea.id { return true }
        return defaultID == nil && teas.count == 1
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.shelfKey),
           let saved = try? JSONDecoder().decode([Tea].self, from: data) {
            teas = saved
        }
        if let raw = UserDefaults.standard.string(forKey: Self.defaultKey),
           let id = UUID(uuidString: raw),
           teas.contains(where: { $0.id == id }) {
            defaultID = id
        }
    }

    @discardableResult
    func add(_ tea: Tea) -> Tea {
        if let key = tea.presetKey, let existing = teas.first(where: { $0.presetKey == key }) {
            return existing
        }
        let first = teas.isEmpty
        teas.append(tea)
        if first {
            defaultID = tea.id
        }
        persist()
        return tea
    }

    func remove(_ tea: Tea) {
        teas.removeAll { $0.id == tea.id }
        if defaultID == tea.id {
            defaultID = nil
        }
        persist()
    }

    func toggleDefault(_ tea: Tea) {
        defaultID = (defaultID == tea.id) ? nil : tea.id
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(teas) {
            UserDefaults.standard.set(data, forKey: Self.shelfKey)
        }
        if let defaultID {
            UserDefaults.standard.set(defaultID.uuidString, forKey: Self.defaultKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.defaultKey)
        }
    }
}

@MainActor
final class BrewEngine: ObservableObject {
    @Published private(set) var tea: Tea?
    @Published private(set) var stepIndex = 0
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var planned: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0

    private var endDate: Date?
    private let alarm = KettleAlarm()
    private static let notifID = "chaicheck.steep.done"

    var step: SteepStep? {
        guard let tea, tea.steps.indices.contains(stepIndex) else { return nil }
        return tea.steps[stepIndex]
    }

    var isOpen: Bool { tea != nil }
    var isLastStep: Bool {
        guard let tea else { return true }
        return stepIndex >= tea.steps.count - 1
    }

    var nextStep: SteepStep? {
        guard let tea, tea.steps.indices.contains(stepIndex + 1) else { return nil }
        return tea.steps[stepIndex + 1]
    }

    func remaining(at now: Date = .now) -> TimeInterval {
        switch phase {
        case .idle:
            return planned
        case .running:
            guard let endDate else { return planned }
            return max(0, endDate.timeIntervalSince(now))
        case .ringing:
            return 0
        }
    }

    func progress(at now: Date = .now) -> Double {
        guard total > 0 else { return 0 }
        switch phase {
        case .idle:
            return 0
        case .running:
            return min(1, max(0, 1 - remaining(at: now) / total))
        case .ringing:
            return 1
        }
    }

    func open(_ tea: Tea) {
        alarm.stop()
        cancelNotification()
        self.tea = tea
        stepIndex = 0
        loadCurrentStep()
        phase = .idle
        StayAwake.on()
    }

    func close() {
        alarm.stop()
        cancelNotification()
        tea = nil
        stepIndex = 0
        phase = .idle
        endDate = nil
        StayAwake.off()
    }

    func start() {
        let duration = remaining(at: .now)
        guard duration > 0, tea != nil else { return }
        requestNotificationsIfNeeded()
        endDate = Date().addingTimeInterval(duration)
        total = duration
        phase = .running
        scheduleNotification(in: duration)
        StayAwake.on()
    }

    func cancelSteep() {
        alarm.stop()
        cancelNotification()
        loadCurrentStep()
        phase = .idle
        endDate = nil
        StayAwake.on()
    }

    func acknowledge() {
        alarm.stop()
        cancelNotification()
        if isLastStep {
            close()
            return
        }
        stepIndex += 1
        loadCurrentStep()
        phase = .idle
        StayAwake.on()
    }

    func tick(at now: Date) {
        guard phase == .running, let endDate else { return }
        if endDate.timeIntervalSince(now) <= 0 {
            complete()
        }
    }

    func syncStayAwake() {
        if tea != nil {
            StayAwake.on()
        } else {
            StayAwake.off()
        }
    }

    private func complete() {
        guard phase == .running else { return }
        phase = .ringing
        endDate = nil
        cancelNotification()
        StayAwake.on()
        alarm.ring()
        Haptics.done()
    }

    private func loadCurrentStep() {
        planned = TimeInterval(step?.seconds ?? 0)
        total = planned
        endDate = nil
    }

    private func requestNotificationsIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(in interval: TimeInterval) {
        cancelNotification()
        guard interval > 0.5, let tea, let step else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(tea.name) is ready"
        content.body = "Steep \(stepIndex + 1) of \(tea.steps.count)" + (step.celsius.map { " · \($0)°C" } ?? "")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: Self.notifID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notifID])
    }
}

enum StayAwake {
    static func on() {
        UIApplication.shared.isIdleTimerDisabled = true
    }

    static func off() {
        UIApplication.shared.isIdleTimerDisabled = false
    }
}

final class KettleAlarm {
    private var player: AVAudioPlayer?

    func ring() {
        stop()
        guard let url = Bundle.main.url(forResource: "ring", withExtension: "wav") else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = 1
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            // Stay-awake screen + haptic still fire if audio fails.
        }
    }

    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

enum TimeFormatting {
    static func clock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(ceil(interval - 0.0001)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

enum Haptics {
    static func tap() {
        UISelectionFeedbackGenerator().selectionChanged()
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
    static let bg = Color(uiColor: .systemBackground)
    static let chip = Color(uiColor: .secondarySystemBackground)
    static let line = Color(uiColor: .separator)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let onFill = Color(uiColor: .systemBackground)
}
