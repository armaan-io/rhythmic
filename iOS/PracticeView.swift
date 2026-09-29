import SwiftUI
import TimingCore

@MainActor
struct PracticeView: View {
    @ObservedObject var model: PracticeModel

    var body: some View {
        Group {
            if model.busy {
                performance
            } else if let result = model.result, model.phase == .review {
                ScrollView {
                    VStack(spacing: 20) {
                        exercisePicker
                        PracticeReviewView(exercise: model.exercise, bpm: model.bpm, result: result)
                            .id(result.performanceStartTime)
                        Button("Retry", action: model.retry)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        Text("Retry returns to preparation. Results are not saved.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding()
                }
            } else {
                preparation
            }
        }
        .alert("Practice", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var exercisePicker: some View {
        Picker("Exercise", selection: Binding(
            get: { model.exercise.id },
            set: { id in
                if let exercise = Exercise.catalog.first(where: { $0.id == id }) { model.select(exercise) }
            }
        )) {
            ForEach(Exercise.catalog) { exercise in
                Text("\(exercise.skill) — \(exercise.title)").tag(exercise.id)
            }
        }
        .pickerStyle(.menu)
        .disabled(model.busy)
    }

    private var preparation: some View {
        ScrollView {
            VStack(spacing: 18) {
                exercisePicker
                Text(model.exercise.title).font(.title2.bold())
                Text(model.exercise.skill).foregroundStyle(.secondary)
                RhythmNotationView(exercise: model.exercise)
                Stepper("\(model.bpm) BPM", value: Binding(get: { model.bpm }, set: model.setBPM), in: 30...240)
                Slider(value: Binding(get: { Double(model.bpm) }, set: { model.setBPM(Int($0.rounded())) }),
                       in: 30...240, step: 1)
                    .accessibilityLabel("Tempo")
                HStack(spacing: 24) {
                    Button("Listen", systemImage: "speaker.wave.2", action: model.listen)
                        .buttonStyle(.bordered)
                    Button("Start", systemImage: "play.fill", action: model.start)
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
                Text(model.message).font(.callout)
                Text("Listen is optional. Start gives four count-in clicks. Tap each note; do not hold it.")
                    .font(.callout).foregroundStyle(.secondary)
                bluetoothWarning
                volumes
                Text("Four exercises · All unlocked · Tempos remembered until the app closes")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
    }

    /// Keep all notation and the pad on-screen during an attempt, without a
    /// scroll gesture competing with touch delivery. Review/preparation may scroll.
    private var performance: some View {
        VStack(spacing: 8) {
            HStack {
                Text(model.exercise.title).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Text("\(model.bpm) BPM").font(.caption.monospacedDigit())
            }
            HStack(spacing: 20) {
                ForEach(1...4, id: \.self) { value in
                    Text("\(value)").font(.title3.monospacedDigit())
                        .frame(width: 36, height: 36)
                        .background(model.beat == value ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Beat \(model.beat.map(String.init) ?? "none")")
            RhythmNotationView(exercise: model.exercise, rowHeight: 88)
            Text(model.message).font(.callout).lineLimit(1).minimumScaleFactor(0.7)
            if model.snapshot?.bluetooth == true {
                Text("Bluetooth audio may lag; scoring is not calibrated.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if model.phase == .listening {
                Spacer(minLength: 4)
                Image(systemName: "speaker.wave.2.fill").font(.largeTitle).accessibilityHidden(true)
                Text("Listen to the snare against the clicks.").font(.callout)
                Spacer(minLength: 4)
                HStack(spacing: 24) {
                    Button("Stop Listening", action: model.listen).buttonStyle(.bordered)
                    Button("Start", action: model.start).buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
            } else {
                TouchPad(enabled: model.phase == .countIn || model.phase == .performing, onContacts: model.tap)
                    .frame(minHeight: 100, maxHeight: .infinity)
                Button("Cancel attempt", action: model.cancel).buttonStyle(.bordered)
            }
        }
        .padding(12)
    }

    @ViewBuilder private var bluetoothWarning: some View {
        if model.snapshot?.bluetooth == true {
            Text("Bluetooth can delay sound. Timing feedback is not latency-calibrated.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var volumes: some View {
        VStack {
            HStack {
                Text("Metronome").frame(width: 100, alignment: .leading)
                Slider(value: $model.metronomeVolume).accessibilityLabel("Metronome volume")
            }
            HStack {
                Text("Rhythm").frame(width: 100, alignment: .leading)
                Slider(value: $model.rhythmVolume).accessibilityLabel("Rhythm volume")
            }
        }
    }
}
