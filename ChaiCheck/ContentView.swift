import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TeaStore
    @EnvironmentObject private var brew: BrewEngine

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color(red: 0.23, green: 0.13, blue: 0.07).opacity(0.9),
                    Theme.bg
                ],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            if brew.isOpen {
                BrewView()
            } else if store.teas.isEmpty {
                EmptyShelf()
            } else {
                ShelfView()
            }
        }
        .sheet(isPresented: $store.adding) {
            AddTeaSheet()
                .environmentObject(store)
                .environmentObject(brew)
                .presentationDetents([.large])
                .preferredColorScheme(.dark)
        }
    }
}

private struct EmptyShelf: View {
    @EnvironmentObject private var store: TeaStore

    var body: some View {
        VStack(spacing: 0) {
            wordmark
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
                            .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
                        Circle()
                            .stroke(Theme.amber.opacity(0.9), lineWidth: 5)
                            .frame(width: 168, height: 168)
                        Circle()
                            .stroke(Theme.line, lineWidth: 2)
                            .frame(width: 132, height: 132)
                        Image(systemName: "plus")
                            .font(.system(size: 58, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.amber)
                    }
                    Text("Add tea")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.cream)
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
            HStack {
                wordmark
                Spacer()
                Button {
                    Haptics.tap()
                    store.adding = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.bg)
                        .frame(width: 36, height: 36)
                        .background(Theme.amber)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add tea")
            }

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.teas) { tea in
                        Button {
                            Haptics.tap()
                            brew.open(tea)
                        } label: {
                            TeaCard(tea: tea)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.remove(tea)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(tea.name)
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                Spacer()
                Text(tea.summary)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
            if tea.tempLine.isEmpty == false {
                Text(tea.tempLine)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.amber)
            }
            Text(tea.note)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Theme.muted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .foregroundStyle(Theme.cream)
                }
            }
        }
    }

    private var featuredSencha: some View {
        Button {
            pick(Preset.sencha)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("SENCHA")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(Theme.amber)
                Text("Daily driver")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(Theme.cream)
                HStack(spacing: 16) {
                    rung(time: "1:00", temp: "70°", label: "base")
                    rung(time: "0:30", temp: "80°", label: "×0.5")
                    rung(time: "2:00", temp: "90°", label: "×2")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.chip)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.amber.opacity(0.7), lineWidth: 1.5)
            )
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
                    .foregroundStyle(Theme.cream)
                    .padding(.vertical, 4)

                HStack {
                    Text("Base time")
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Button {
                        customBase = max(15, customBase - 15)
                    } label: {
                        Text("−15s")
                            .foregroundStyle(Theme.cream)
                    }
                    Text(TimeFormatting.clock(TimeInterval(customBase)))
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.cream)
                        .frame(minWidth: 64)
                    Button {
                        customBase = min(20 * 60, customBase + 15)
                    } label: {
                        Text("+15s")
                            .foregroundStyle(Theme.cream)
                    }
                }
                .font(.system(size: 16, weight: .medium, design: .rounded))

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
                        .foregroundStyle(Theme.bg)
                        .background(Theme.amber)
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
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tea.name)
                                .font(.system(size: 20, weight: .medium, design: .serif))
                                .foregroundStyle(Theme.cream)
                            Text(tea.note)
                                .font(.system(size: 13, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(Theme.muted)
                                .lineLimit(2)
                        }
                        Spacer()
                        Text(tea.summary)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.amber)
                    }
                    .padding(16)
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
                .foregroundStyle(Theme.cream)
            Text(temp)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.amber)
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
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.cream)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("CHAICHECK")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(3.2)
                .foregroundStyle(Theme.muted)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.top, 8)
    }

    private var identity: some View {
        VStack(spacing: 6) {
            Text(brew.tea?.name ?? "")
                .font(.system(size: 34, weight: .medium, design: .serif))
                .foregroundStyle(Theme.cream)
            if let tea = brew.tea, let step = brew.step {
                Text("Steep \(brew.stepIndex + 1) of \(tea.steps.count)  ·  \(step.rung)")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
        }
    }

    private func timer(remaining: TimeInterval, progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.line, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    brew.phase == .ringing ? Theme.cream : Theme.amber,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if brew.phase == .ringing {
                Text("READY")
                    .font(.system(size: 42, weight: .medium, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(Theme.cream)
            } else {
                Text(TimeFormatting.clock(remaining))
                    .font(.system(size: 76, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.cream)
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
                        .foregroundStyle(Theme.amber)
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
                        .foregroundStyle(Theme.cream)
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
                        .foregroundStyle(Theme.bg)
                        .background(Theme.amber)
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

private var wordmark: some View {
    Text("CHAICHECK")
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .tracking(3.2)
        .foregroundStyle(Theme.muted)
        .padding(.top, 8)
}

#Preview("Empty") {
    ContentView()
        .environmentObject(TeaStore())
        .environmentObject(BrewEngine())
        .preferredColorScheme(.dark)
}
