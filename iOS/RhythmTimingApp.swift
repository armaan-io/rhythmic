import SwiftUI
import TimingCore

@main
@MainActor
struct RhythmTimingApp: App {
    @StateObject private var practice = PracticeModel()
    @StateObject private var preferences = AppPreferences()
    @State private var path: [String] = []
    #if DEBUG
    @StateObject private var model = TimingHarnessModel()
    @State private var diagnosticsPresented = false
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                List {
                    ForEach(Exercise.catalog) { exercise in
                        Section(libraryHeading(for: exercise)) {
                            Button {
                                practice.select(exercise)
                                path.append(exercise.id)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(exercise.title).font(.headline).foregroundStyle(.primary)
                                        Text("\(exercise.barCount) \(exercise.barCount == 1 ? "bar" : "bars")")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary).accessibilityHidden(true)
                                }.padding(.vertical, 12).contentShape(Rectangle())
                            }
                            .listRowBackground(AppTheme.surface)
                        }
                    }
                }
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.background)
                    .navigationTitle("Exercises")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Settings", systemImage: "gearshape") { path.append("settings") }
                        }
                        #if DEBUG
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Diagnostics", systemImage: "waveform.path.ecg") {
                                diagnosticsPresented = true
                            }
                        }
                        #endif
                    }
                    .navigationDestination(for: String.self) { destination in
                        if destination == "settings" {
                            SettingsView(model: practice, preferences: preferences)
                        } else {
                            PracticeView(model: practice, preferences: preferences) { path.removeAll() }
                        }
                    }
            }
                .tint(AppTheme.accent)
                .preferredColorScheme(preferences.appearance.colorScheme)
                #if DEBUG
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
                #endif
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        #if DEBUG
                        model.leaveActiveScene()
                        #endif
                        practice.leaveActiveScene()
                    }
                }
        }
    }

    private func libraryHeading(for exercise: Exercise) -> String {
        switch exercise.skill {
        case "Quarter-note timing": return "Quarters"
        case "Eighth-note subdivisions": return "Eighth Notes"
        case "Simple syncopation": return "Syncopation"
        default: return exercise.skill
        }
    }
}

#if DEBUG
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
#endif
