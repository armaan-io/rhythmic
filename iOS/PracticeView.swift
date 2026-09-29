import SwiftUI
import TimingCore

@MainActor
struct PracticeView: View {
    @ObservedObject var model: PracticeModel
    @ObservedObject var preferences: AppPreferences
    let returnToLibrary: () -> Void
    @State private var editor: Editor?

    private enum Editor: String, Identifiable {
        case tempo, volume, bluetooth
        var id: String { rawValue }
    }
    private var attempting: Bool { model.busy && model.phase != .listening }

    var body: some View {
        Group {
            if let result = model.result, model.phase == .review {
                ScrollView {
                    PracticeReviewView(exercise: model.exercise, bpm: model.bpm, result: result)
                        .id(result.performanceStartTime)
                        .padding(20)
                }
                .safeAreaInset(edge: .bottom) {
                    Button(action: model.retry) {
                        Text("Retry").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .foregroundStyle(AppTheme.onAccent)
                    .padding().background(AppTheme.background)
                }
            } else {
                GeometryReader { geometry in
                    practiceLayout(height: geometry.size.height)
                }
            }
        }
        .background(AppTheme.background)
        .navigationTitle(model.phase == .review ? "Review" : model.exercise.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if attempting {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: model.cancel)
                }
            } else {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Library", systemImage: "chevron.left") {
                        model.cancel()
                        returnToLibrary()
                    }
                }
            }
        }
        .sheet(item: $editor) { item in
            switch item {
            case .tempo:
                EditorSheet(title: "Tempo") {
                    VStack(spacing: 24) {
                        Text("\(model.bpm) BPM").font(.largeTitle.monospacedDigit())
                        Slider(value: Binding(get: { Double(model.bpm) }, set: { model.setBPM(Int($0.rounded())) }),
                               in: 30...240, step: 1).accessibilityLabel("Tempo")
                        Stepper("\(model.bpm) BPM", value: Binding(get: { model.bpm }, set: model.setBPM), in: 30...240)
                    }.disabled(model.busy)
                }
            case .volume:
                EditorSheet(title: "Volume") { AudioControls(model: model) }
            case .bluetooth:
                EditorSheet(title: "Bluetooth audio") {
                    Text("Wireless audio can delay the metronome and your tap sounds. Timing feedback is not calibrated for that delay. For more reliable practice, use the speaker or wired headphones.")
                }
            }
        }
        .alert("Unable to play", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK") { model.errorMessage = nil } }
        message: { Text(model.errorMessage ?? "") }
    }

    private func practiceLayout(height: CGFloat) -> some View {
        // Identical musical geometry for preparation, Listen, and Play. Only the
        // lower interaction region changes. Compact heights protect the pad.
        let compact = height < 620
        let rowHeight: CGFloat = compact ? 80 : 104
        let spacing: CGFloat = compact ? 4 : 12
        return VStack(spacing: spacing) {
            HStack(spacing: 12) {
                Button { editor = .tempo } label: {
                    Text("\(model.bpm) BPM").font(.subheadline.weight(.medium).monospacedDigit())
                        .padding(.horizontal, 12).frame(minHeight: 44)
                }.disabled(model.busy)
                    .accessibilityLabel("Tempo, \(model.bpm) beats per minute")
                Spacer()
                Button { editor = .volume } label: {
                    Image(systemName: "speaker.wave.2").frame(width: 44, height: 44)
                }.accessibilityLabel("Volume")
            }
            .opacity(attempting ? 0 : 1)
            .allowsHitTesting(!attempting).accessibilityHidden(attempting)

            HStack(spacing: 20) {
                ForEach(1...4, id: \.self) { value in
                    Text("\(value)").font(.system(.body, design: .rounded).monospacedDigit())
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .foregroundStyle(model.beat == value ? Color.white : Color.primary)
                        .frame(width: 36, height: 36)
                        .background(model.beat == value ? AppTheme.beat : AppTheme.surface, in: Circle())
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Beat \(model.beat.map(String.init) ?? "none")")
            Text(phaseLabel).font(.caption).foregroundStyle(.secondary)
                .lineLimit(2).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 40 : 56)
            RhythmNotationView(exercise: model.exercise, rowHeight: rowHeight)

            if attempting {
                TouchPad(enabled: model.phase == .countIn || model.phase == .performing,
                         hapticsEnabled: preferences.hapticsEnabled, onContacts: model.tap)
                    .frame(minHeight: 80, maxHeight: .infinity)
            } else {
                GeometryReader { controls in
                    ScrollView {
                        preparationControls
                            .frame(minHeight: controls.size.height)
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, compact ? 8 : 16)
    }

    // Only supporting controls scroll. The musical region never changes its
    // screen position when Play is pressed after scrolling at a large text size.
    private var preparationControls: some View {
        VStack(spacing: 12) {
            if model.phase == .cancelled, model.message != "Ready" {
                Text(model.message).font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if model.phase != .listening, model.bluetoothConnected {
                Button { editor = .bluetooth } label: {
                    Label("Bluetooth may delay sound", systemImage: "info.circle")
                        .font(.footnote).frame(minHeight: 44)
                }
            }
            Spacer(minLength: 20)
            playbackControls
            Text("Play begins with four count-in beats.")
                .font(.footnote).foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
    }

    private var playbackControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { listenButton; playButton }
            VStack(spacing: 12) { listenButton; playButton }
        }.controlSize(.large)
    }
    private var listenButton: some View {
        Button(model.phase == .listening ? "Stop Listening" : "Listen",
               systemImage: model.phase == .listening ? "stop.fill" : "speaker.wave.2",
               action: model.listen).buttonStyle(.bordered)
    }
    private var playButton: some View {
        Button("Play", systemImage: "play.fill", action: model.start)
            .buttonStyle(.borderedProminent)
            .foregroundStyle(AppTheme.onAccent)
    }
    private var phaseLabel: String {
        switch model.phase {
        case .countIn: return "Count-in"
        case .performing: return "Bar \(max(1, model.bar)) of \(model.exercise.barCount)"
        case .listening: return "Listening · Bar \(max(1, model.bar)) of \(model.exercise.barCount)"
        default: return "Ready"
        }
    }
}
