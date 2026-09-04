import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var engine: SteepEngine

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: engine.phase != .running)) { timeline in
            let remaining = engine.remaining(at: timeline.date)
            let progress = engine.progress(at: timeline.date)

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

                VStack(spacing: 0) {
                    header
                    Spacer(minLength: 12)
                    teaIdentity
                    timer(remaining: remaining, progress: progress)
                    meta
                    Spacer(minLength: 12)
                    controls
                    teaStrip
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
            .onChange(of: timeline.date) { _, date in
                engine.tick(at: date)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("CHAICHECK")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(3.2)
                .foregroundStyle(Theme.muted)
            Spacer()
            if engine.phase == .done {
                Button("Reset") {
                    Haptics.tap()
                    engine.reset()
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.cream)
            } else if engine.isActive {
                Button("Cancel") {
                    Haptics.tap()
                    engine.cancel()
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.cream)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var teaIdentity: some View {
        VStack(spacing: 6) {
            Text(engine.tea.name)
                .font(.system(size: 36, weight: .medium, design: .serif))
                .foregroundStyle(Theme.cream)
            Text(engine.subtitle)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private func timer(remaining: TimeInterval, progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.line, lineWidth: 12)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    engine.phase == .done ? Theme.cream : Theme.amber,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: progress)

            VStack(spacing: 4) {
                if engine.phase == .done {
                    Text(engine.isRinse ? "RINSED" : "READY")
                        .font(.system(size: 42, weight: .medium, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(Theme.cream)
                } else {
                    Text(engine.formatted(remaining))
                        .font(.system(size: 76, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Theme.cream)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 28)
        }
        .frame(width: 280, height: 280)
        .padding(.vertical, 28)
        .accessibilityLabel(timerLabel(remaining: remaining))
    }

    private var meta: some View {
        VStack(spacing: 6) {
            Text(engine.waterLine)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.amber)
            if let next = engine.nextLine, engine.phase != .done {
                Text(next)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.muted)
            }
            Text(engine.tea.note)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(.horizontal, 8)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            if engine.phase != .done {
                HStack(spacing: 12) {
                    nudgeButton(title: "−15s", delta: -15)
                    nudgeButton(title: "+30s", delta: 30)
                }
            }

            Button(action: primaryAction) {
                Text(engine.primaryTitle)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .foregroundStyle(primaryForeground)
                    .background(primaryBackground)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Theme.amber.opacity(engine.phase == .running ? 0.9 : 0), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.startsMediaSession)
        }
        .padding(.bottom, 18)
    }

    private var teaStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Tea.all) { tea in
                        Button {
                            engine.select(tea)
                        } label: {
                            Text(tea.name)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .padding(.horizontal, 14)
                                .frame(height: 40)
                                .foregroundStyle(engine.tea.id == tea.id ? Theme.bg : Theme.cream)
                                .background(engine.tea.id == tea.id ? Theme.amber : Theme.chip)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.phase == .running)
                        .opacity(engine.phase == .running && engine.tea.id != tea.id ? 0.45 : 1)
                        .id(tea.id)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .onAppear {
                proxy.scrollTo(engine.tea.id, anchor: .center)
            }
            .onChange(of: engine.tea.id) { _, id in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func nudgeButton(title: String, delta: TimeInterval) -> some View {
        Button {
            engine.nudge(delta)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .foregroundStyle(Theme.cream)
                .background(Theme.chip)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var primaryForeground: Color {
        engine.phase == .running ? Theme.amber : Theme.bg
    }

    private var primaryBackground: Color {
        engine.phase == .running ? Theme.chip : Theme.amber
    }

    private func primaryAction() {
        Haptics.tap()
        switch engine.phase {
        case .idle:
            engine.start()
        case .running:
            engine.pause()
        case .paused:
            engine.resume()
        case .done:
            engine.advance()
        }
    }

    private func timerLabel(remaining: TimeInterval) -> String {
        if engine.phase == .done {
            return engine.isRinse ? "Rinse finished" : "Tea is ready"
        }
        let seconds = max(0, Int(ceil(remaining - 0.0001)))
        return "\(seconds / 60) minutes \(seconds % 60) seconds remaining"
    }
}

#Preview {
    ContentView()
        .environmentObject(SteepEngine())
        .preferredColorScheme(.dark)
}
