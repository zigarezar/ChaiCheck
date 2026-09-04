import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TeaStore
    @EnvironmentObject private var brew: BrewEngine
    @State private var openedDefault = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            if brew.isOpen {
                BrewView()
            } else if store.teas.isEmpty {
                EmptyShelf()
            } else {
                ShelfView()
            }
        }
        .onAppear {
            guard !openedDefault else { return }
            openedDefault = true
            if let tea = store.defaultTea {
                brew.open(tea)
            }
        }
        .sheet(isPresented: $store.adding) {
            AddTeaSheet()
                .environmentObject(store)
                .environmentObject(brew)
                .presentationDetents([.large])
        }
        .sheet(item: $store.editing) { tea in
            EditTeaSheet(tea: tea)
                .environmentObject(store)
                .presentationDetents([.large])
        }
    }
}

private struct EmptyShelf: View {
    @EnvironmentObject private var store: TeaStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Button {
                Haptics.tap()
                store.adding = true
            } label: {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Theme.chip)
                            .frame(width: 168, height: 168)
                            .shadow(color: Color.primary.opacity(0.12), radius: 18, y: 10)
                        Circle()
                            .stroke(Theme.ink.opacity(0.85), lineWidth: 5)
                            .frame(width: 168, height: 168)
                        Circle()
                            .stroke(Theme.line, lineWidth: 2)
                            .frame(width: 132, height: 132)
                        Image(systemName: "plus")
                            .font(.system(size: 58, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.ink)
                    }
                    Text("Add tea")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add tea")
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

private struct ShelfView: View {
    @EnvironmentObject private var store: TeaStore
    @EnvironmentObject private var brew: BrewEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.teas) { tea in
                        TeaCard(
                            tea: tea,
                            isDefault: store.isDefault(tea),
                            onOpen: {
                                Haptics.tap()
                                brew.open(tea)
                            },
                            onPin: {
                                Haptics.tap()
                                store.toggleDefault(tea)
                            }
                        )
                        .contextMenu {
                            Button {
                                store.editing = tea
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button {
                                store.toggleDefault(tea)
                            } label: {
                                Label(
                                    store.isDefault(tea) ? "Clear default" : "Use as default",
                                    systemImage: store.isDefault(tea) ? "pin.slash" : "pin"
                                )
                            }
                            Button(role: .destructive) {
                                store.remove(tea)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }

                    Button {
                        Haptics.tap()
                        store.adding = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Add tea")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.chip)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add tea")
                    .padding(.top, 4)
                }
                .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

private struct TeaCard: View {
    let tea: Tea
    let isDefault: Bool
    let onOpen: () -> Void
    let onPin: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tea.liquor
                .frame(width: 5)
                .accessibilityHidden(true)

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(tea.name)
                            .font(.system(size: 28, weight: .medium, design: .serif))
                            .foregroundStyle(Theme.ink)
                        Spacer(minLength: 8)
                        Text(tea.summary)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.muted)
                    }
                    if tea.tempLine.isEmpty == false {
                        Text(tea.tempLine)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.muted)
                    }
                    Text(tea.note)
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 18)
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onPin) {
                VStack(spacing: 4) {
                    Image(systemName: isDefault ? "pin.fill" : "pin")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isDefault ? Theme.ink : Theme.muted)
                    if isDefault {
                        Text("DEFAULT")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 56, height: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDefault ? "Default tea, tap to clear" : "Make default")
            .padding(.trailing, 6)
        }
        .background(Theme.chip)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct AddTeaSheet: View {
    @EnvironmentObject private var store: TeaStore
    @EnvironmentObject private var brew: BrewEngine
    @Environment(\.dismiss) private var dismiss

    @State private var customName = ""
    @State private var customBase = 60

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    featuredSencha
                    customBlock
                    otherPresets
                }
                .padding(20)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Add tea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var featuredSencha: some View {
        Button {
            pick(Preset.sencha)
        } label: {
            HStack(spacing: 0) {
                Preset.sencha.liquor
                    .frame(width: 5)
                VStack(alignment: .leading, spacing: 10) {
                    Text("SENCHA")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .tracking(2.4)
                        .foregroundStyle(Theme.muted)
                    Text("Daily driver")
                        .font(.system(size: 28, weight: .medium, design: .serif))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 16) {
                        rung(time: "1:00", temp: "70°", label: "base")
                        rung(time: "0:30", temp: "80°", label: "×0.5")
                        rung(time: "2:00", temp: "90°", label: "×2")
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.chip)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var customBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CUSTOM")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(Theme.muted)

            VStack(alignment: .leading, spacing: 14) {
                TextField("Name", text: $customName)
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 4)

                DurationWheels(totalSeconds: $customBase)

                HStack(spacing: 16) {
                    ForEach(Ladder.steps(baseSeconds: customBase, temps: [70, 80, 90]), id: \.rung) { step in
                        rung(
                            time: TimeFormatting.clock(TimeInterval(step.seconds)),
                            temp: step.celsius.map { "\($0)°" } ?? "",
                            label: step.rung
                        )
                    }
                }

                Button {
                    let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let tea = Ladder.senchaStyle(
                        name: name.isEmpty ? "Custom" : name,
                        baseSeconds: customBase,
                        note: "Base \(TimeFormatting.clock(TimeInterval(customBase))) · ×0.5 · ×2"
                    )
                    pick(tea)
                } label: {
                    Text("Add custom")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .foregroundStyle(Theme.onFill)
                        .background(Theme.ink)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(Theme.chip)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var otherPresets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRESETS")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(Theme.muted)

            ForEach(Preset.all.filter { $0.presetKey != "sencha" }) { tea in
                Button {
                    pick(tea)
                } label: {
                    HStack(spacing: 0) {
                        tea.liquor
                            .frame(width: 5)
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tea.name)
                                    .font(.system(size: 20, weight: .medium, design: .serif))
                                    .foregroundStyle(Theme.ink)
                                Text(tea.note)
                                    .font(.system(size: 13, weight: .regular, design: .serif))
                                    .italic()
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Text(tea.summary)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(16)
                    }
                    .background(Theme.chip)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func rung(time: String, temp: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(time)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(temp)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
            Text(label)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func pick(_ tea: Tea) {
        Haptics.tap()
        let added = store.add(tea)
        dismiss()
        brew.open(added)
    }
}

private struct DurationWheels: View {
    @Binding var totalSeconds: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("Minutes", selection: minutes) {
                ForEach(0..<60, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Minutes")

            Text("min")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
                .padding(.trailing, 12)

            Picker("Seconds", selection: seconds) {
                ForEach(0..<60, id: \.self) { value in
                    Text(String(format: "%02d", value)).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Seconds")

            Text("sec")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.muted)
        }
        .frame(height: 140)
        .clipped()
    }

    private var minutes: Binding<Int> {
        Binding(
            get: { totalSeconds / 60 },
            set: { totalSeconds = max(1, min(59 * 60 + 59, $0 * 60 + totalSeconds % 60)) }
        )
    }

    private var seconds: Binding<Int> {
        Binding(
            get: { totalSeconds % 60 },
            set: { totalSeconds = max(1, min(59 * 60 + 59, (totalSeconds / 60) * 60 + $0)) }
        )
    }
}

private struct EditTeaSheet: View {
    @EnvironmentObject private var store: TeaStore
    @Environment(\.dismiss) private var dismiss

    let teaID: UUID
    let presetKey: String?
    @State private var name: String
    @State private var steps: [SteepStep]
    @State private var note: String

    init(tea: Tea) {
        teaID = tea.id
        presetKey = tea.presetKey
        _name = State(initialValue: tea.name)
        _steps = State(initialValue: tea.steps)
        _note = State(initialValue: tea.note)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .font(.system(size: 22, weight: .medium, design: .serif))
                }

                ForEach($steps) { $step in
                    Section {
                        DurationWheels(totalSeconds: $step.seconds)
                            .listRowInsets(EdgeInsets())
                    } header: {
                        HStack {
                            Text(step.rung)
                            Spacer()
                            if let celsius = step.celsius {
                                Text("\(celsius)°C")
                            }
                        }
                    }
                }

                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit tea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        store.update(
            Tea(
                id: teaID,
                name: trimmed.isEmpty ? "Tea" : trimmed,
                steps: steps,
                note: note,
                presetKey: presetKey
            )
        )
        Haptics.tap()
        dismiss()
    }
}

private struct BrewView: View {
    @EnvironmentObject private var brew: BrewEngine

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: brew.phase != .running)) { timeline in
            let remaining = brew.remaining(at: timeline.date)
            let progress = brew.progress(at: timeline.date)

            VStack(spacing: 0) {
                header
                Spacer(minLength: 8)
                identity
                timer(remaining: remaining, progress: progress)
                meta
                Spacer(minLength: 8)
                controls
                Text("Screen stays on while you brew.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 20)
            .onChange(of: timeline.date) { _, date in
                brew.tick(at: date)
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                Haptics.tap()
                brew.close()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Select")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundStyle(Theme.ink)
                .frame(height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select tea")
            Spacer()
        }
        .padding(.top, 8)
    }

    private var identity: some View {
        VStack(spacing: 6) {
            Text(brew.tea?.name ?? "")
                .font(.system(size: 34, weight: .medium, design: .serif))
                .foregroundStyle(Theme.ink)
            if let tea = brew.tea, let step = brew.step {
                Text("Steep \(brew.stepIndex + 1) of \(tea.steps.count)  ·  \(step.rung)")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func timer(remaining: TimeInterval, progress: Double) -> some View {
        let liquor = brew.tea?.liquor ?? Theme.ink
        return ZStack {
            Circle()
                .stroke(Theme.line, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    brew.phase == .ringing ? Theme.ink : liquor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if brew.phase == .ringing {
                Text("READY")
                    .font(.system(size: 42, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.ink)
            } else {
                Text(TimeFormatting.clock(remaining))
                    .font(.system(size: 76, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 28)
            }
        }
        .frame(width: 280, height: 280)
        .padding(.vertical, 24)
        .accessibilityLabel(timerLabel(remaining: remaining))
    }

    @ViewBuilder
    private var meta: some View {
        if let step = brew.step {
            VStack(spacing: 6) {
                if let celsius = step.celsius {
                    Text("\(celsius)°C water")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.ink)
                }
                if brew.phase == .ringing, let next = brew.nextStep {
                    Text("Next  ·  \(TimeFormatting.clock(TimeInterval(next.seconds)))" + (next.celsius.map { "  ·  \($0)°C" } ?? ""))
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            if brew.phase == .running {
                Button {
                    Haptics.tap()
                    brew.cancelSteep()
                } label: {
                    Text("Cancel steep")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Theme.chip)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    Haptics.tap()
                    if brew.phase == .ringing {
                        brew.acknowledge()
                    } else {
                        brew.start()
                    }
                } label: {
                    Text(primaryTitle)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(Theme.onFill)
                        .background(Theme.ink)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var primaryTitle: String {
        if brew.phase == .ringing {
            return brew.isLastStep ? "Done" : "Next steep"
        }
        if let step = brew.step, step.rung == "rinse" {
            return "Rinse"
        }
        if let step = brew.step, step.rung == "simmer" {
            return "Simmer"
        }
        return "Steep"
    }

    private func timerLabel(remaining: TimeInterval) -> String {
        if brew.phase == .ringing { return "Tea is ready" }
        let seconds = max(0, Int(ceil(remaining - 0.0001)))
        return "\(seconds / 60) minutes \(seconds % 60) seconds remaining"
    }
}

#Preview("Empty") {
    ContentView()
        .environmentObject(TeaStore())
        .environmentObject(BrewEngine())
}
