import SwiftUI

@main
@MainActor
struct RhythmTimingApp: App {
    @StateObject private var model = TimingHarnessModel()
    @StateObject private var practice = PracticeModel()
    @State private var diagnosticsPresented = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                PracticeView(model: practice)
                    .navigationTitle("Rhythm Trainer")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Diagnostics", systemImage: "waveform.path.ecg") {
                                diagnosticsPresented = true
                            }
                            .disabled(practice.busy)
                        }
                    }
            }
                .sheet(isPresented: $diagnosticsPresented) {
                    NavigationStack {
                        HarnessView(model: model)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") {
                                        model.leaveActiveScene()
                                        diagnosticsPresented = false
                                    }
                                }
                            }
                    }
                    .onDisappear { model.leaveActiveScene() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        model.leaveActiveScene()
                        practice.leaveActiveScene()
                    }
                }
        }
    }
}

@MainActor
private struct HarnessView: View {
    @ObservedObject var model: TimingHarnessModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Rhythm Timing").font(.title.bold())
                Text("Raw timing test • 16 bars • no score").font(.subheadline)
                if model.snapshot?.bluetooth == true {
                    Text("Bluetooth can delay tap sounds. These diagnostics are not calibrated.")
                        .font(.callout.bold())
                        .accessibilityAddTraits(.isStaticText)
                }
                VStack {
                    Stepper("\(model.bpm) BPM", value: $model.bpm, in: 30...240)
                    Slider(value: Binding(get: { Double(model.bpm) }, set: { model.bpm = Int($0.rounded()) }),
                           in: 30...240, step: 1)
                        .accessibilityLabel("Tempo")
                }
                .disabled(model.busy)
                HStack(spacing: 20) {
                    ForEach(1...4, id: \.self) { beat in
                        Text("\(beat)").font(.title2.monospacedDigit())
                            .frame(width: 44, height: 44)
                            .background(model.beat == beat ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Beat \(model.beat.map(String.init) ?? "none"), bar \(model.bar)")
                Text(model.status).font(.callout)
                Button(model.busy ? "Stop" : "Start") {
                    if model.busy { model.stop() } else { model.start() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                TouchPad(enabled: model.running, onContacts: model.tap)
                    .frame(height: 250)
                    .contentShape(Rectangle())
                Text("\(model.tapCount) contacts recorded").font(.caption.monospacedDigit())
                volume("Metronome", value: $model.metronomeVolume)
                volume("Rhythm", value: $model.rhythmVolume)
                if let audio = model.snapshot {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Output: " + audio.outputs.map { "\($0.name) (\($0.type))" }.joined(separator: ", "))
                        Text("\(audio.sampleRate, specifier: "%.0f") Hz • I/O \(audio.ioBufferDuration * 1000, specifier: "%.2f") ms")
                        Text("Reported output \(audio.outputLatency * 1000, specifier: "%.2f") ms • engine presentation \(audio.engineOutputPresentationLatency * 1000, specifier: "%.2f") ms")
                        Text("System reports, not measured acoustic latency. Snapshot at start/stop.")
                    }
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let document = model.document {
                    ShareLink(item: document,
                              preview: SharePreview("Rhythm timing diagnostics", image: Image(systemName: "waveform.path"))) {
                        Label("Share JSON diagnostics", systemImage: "square.and.arrow.up")
                    }
                        .buttonStyle(.bordered)
                }
                Text("Quarter-note clicks accent beat 1. A short audio preparation delay precedes the first beat; there is no musical count-in. Keep the app active.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .alert("Timing harness", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func volume(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title).frame(width: 100, alignment: .leading)
            Slider(value: value, in: 0...1).accessibilityLabel("\(title) volume")
        }
    }
}
