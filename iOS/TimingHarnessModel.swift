import AVFoundation
import Combine
import CoreTransferable
import SwiftUI
import TimingCore
import UIKit
import UniformTypeIdentifiers

struct DiagnosticDocument: Transferable, Sendable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { document in document.data }
            .suggestedFileName("rhythm-timing-diagnostics.json")
    }
}

private struct RunDiagnostics: Encodable {
    let schemaVersion = 1
    let session: TimingSession
    let outcome: String
    let audioAtStart: AudioSnapshot
    let audioAtStop: AudioSnapshot
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let preRollSeconds = 0.25
    let tapVoicePoolSize = 16
    let tapVoiceSteals: Int
    let renderedSampleRate: Double
    let initialMetronomeVolume: Double
    let initialRhythmVolume: Double
    let finalMetronomeVolume: Double
    let finalRhythmVolume: Double
    let clockRationale = "UITouch.timestamp, ProcessInfo.systemUptime receipt time, and AVAudioTime host-time seconds use the system uptime timebase. Planned beats are requested host times, rounded to the nearest PCM frame relative to start. UI updates do not schedule audio. No latency correction is applied. Event-to-beat differences are not physical acoustic latency measurements."
    let soundPolicy = "One mono PCM metronome buffer at actual engine sample rate; deterministic 80 ms dry snare taps with 16 preattached voices, oldest voice stolen on wrap. Rhythm gain is divided by the active voice count on hits/level changes for summing headroom. Volume sliders remain live; only initial/final levels are captured."
}

@MainActor
final class TimingHarnessModel: ObservableObject {
    @Published var bpm = 120
    @Published var metronomeVolume = 0.7 { didSet { updateVolumes() } }
    @Published var rhythmVolume = 0.7 { didSet { updateVolumes() } }
    @Published private(set) var busy = false
    @Published private(set) var running = false
    @Published private(set) var status = "Ready — 16 bars, no scoring"
    @Published private(set) var beat: Int?
    @Published private(set) var bar = 0
    @Published private(set) var tapCount = 0
    @Published private(set) var snapshot: AudioSnapshot?
    @Published private(set) var document: DiagnosticDocument?
    @Published var errorMessage: String?

    private var audio: TimingAudio?
    private var session: TimingSession?
    private var initialSnapshot: AudioSnapshot?
    private var initialVolumes = (0.7, 0.7)
    private var observers: [NSObjectProtocol] = []
    private var displayTimer: Timer?
    private var startup: Task<Void, Never>?
    private var generation = UUID()
    private var armedAt = Double.infinity

    func start() {
        guard !busy else { return }
        document = nil
        errorMessage = nil
        session = nil
        snapshot = nil
        initialSnapshot = nil
        tapCount = 0
        beat = nil
        bar = 0
        busy = true
        status = "Preparing audio…"
        armedAt = .infinity
        let token = UUID()
        generation = token
        let audio = TimingAudio()
        self.audio = audio
        observe(audio: audio, token: token)
        do {
            try audio.prepare(metronomeVolume: Float(metronomeVolume), rhythmVolume: Float(rhythmVolume))
            try audio.render(bpm: bpm)
        } catch {
            failStartup(error)
            return
        }
        // Let activation/configuration notifications drain before arming. Interruption
        // and media-service failure still abort preparation; no automatic resume.
        startup = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled, let self, self.busy, self.generation == token else { return }
            do {
                let now = ProcessInfo.processInfo.systemUptime
                let newSession = try TimingSession(bpm: self.bpm, startTime: now + 0.25)
                self.session = newSession
                self.initialVolumes = (self.metronomeVolume, self.rhythmVolume)
                let snapshot = AudioSnapshot.capture(engine: audio.engine)
                self.snapshot = snapshot
                self.initialSnapshot = snapshot
                try audio.schedule(session: newSession)
                self.armedAt = now
                self.running = true
                self.status = "Starting…"
                let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.observeTime() }
                }
                self.displayTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            } catch { self.failStartup(error) }
        }
    }

    func tap(contacts: [PadContact]) -> Bool {
        guard running, let endTime = session?.endTime else { return false }
        // Mutate storage in place: copying a session first would copy its entire
        // growing tap array on every contact through Array's copy-on-write path.
        // Process the whole UIKit batch before closing the session. A delayed
        // delivery must not discard all but the first simultaneous contact.
        var anyAccepted = false
        var observedEnd = false
        for contact in contacts {
            let accepted = session?.recordTap(eventTime: contact.eventTime,
                                               receivedTime: contact.receivedTime) ?? false
            anyAccepted = anyAccepted || accepted
            observedEnd = observedEnd || contact.receivedTime >= endTime
            if accepted && contact.receivedTime < endTime {
                audio?.playHit(now: contact.receivedTime)
            }
        }
        tapCount = session?.taps.count ?? 0
        if let stop = session?.stopEvent {
            finish(reason: stop.reason, at: stop.time)
            return false
        }
        if observedEnd {
            finish(reason: .completed, at: endTime)
        }
        // Late-delivered contacts may be logged, but never produce a new sound
        // beyond the run boundary. A fully finalized run accepts no new batch.
        return anyAccepted
    }

    func stop() { finish(reason: .manual) }
    func leaveActiveScene() { if busy { finish(reason: .backgrounded) } }

    private func observeTime() {
        guard running, let session else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now < session.endTime else {
            finish(reason: .completed, at: session.endTime)
            return
        }
        guard audio?.engine.isRunning == true else {
            finish(reason: .audioFailure)
            errorMessage = "Audio engine stopped unexpectedly. Diagnostics are cancelled."
            return
        }
        guard now >= session.startTime else { return }
        let index = min(session.beats.count - 1, Int((now - session.startTime) / session.beatInterval))
        beat = index % 4 + 1
        bar = index / 4 + 1
        status = "Running — bar \(bar) of 16"
    }

    private func finish(reason: StopReason, at time: Double? = nil) {
        guard busy else { return }
        let stopTime = time ?? ProcessInfo.processInfo.systemUptime
        startup?.cancel()
        displayTimer?.invalidate()
        displayTimer = nil
        removeObservers()
        let endSnapshot = audio.map { AudioSnapshot.capture(engine: $0.engine) }
        // Shut down immediately, before JSON serialization or other result work.
        audio?.shutdown()
        if var current = session, let audio, let initialSnapshot, let endSnapshot {
            current.stop(at: stopTime, reason: reason)
            session = current
            snapshot = endSnapshot
            let actualReason = current.stopEvent?.reason ?? reason
            let outcome = actualReason == .completed ? "completed" : "cancelled"
            status = "\(outcome.capitalized) diagnostics — \(actualReason.rawValue)"
            let diagnostics = RunDiagnostics(
                session: current, outcome: outcome, audioAtStart: initialSnapshot, audioAtStop: endSnapshot,
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                osVersion: UIDevice.current.systemVersion, deviceModel: UIDevice.current.model,
                tapVoiceSteals: audio.voiceSteals,
                renderedSampleRate: audio.sampleRate,
                initialMetronomeVolume: initialVolumes.0, initialRhythmVolume: initialVolumes.1,
                finalMetronomeVolume: metronomeVolume, finalRhythmVolume: rhythmVolume
            )
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                document = DiagnosticDocument(data: try encoder.encode(diagnostics))
            } catch { errorMessage = "Could not encode diagnostics: \(error.localizedDescription)" }
        } else {
            status = "Preparation cancelled — \(reason.rawValue)"
        }
        audio = nil
        running = false
        busy = false
        beat = nil
        armedAt = .infinity
    }

    private func failStartup(_ error: Error) {
        finish(reason: .audioFailure)
        errorMessage = "Unable to start: \(error.localizedDescription)"
    }

    private func updateVolumes() {
        audio?.setVolumes(metronome: Float(metronomeVolume), rhythm: Float(rhythmVolume))
    }

    private func observe(audio: TimingAudio, token: UUID) {
        let center = NotificationCenter.default
        func add(_ name: Notification.Name, object: AnyObject?, reason: StopReason, startupFatal: Bool) {
            observers.append(center.addObserver(forName: name, object: object, queue: nil) { [weak self] note in
                // Capture at notification delivery, before hopping to the UI executor.
                let time = ProcessInfo.processInfo.systemUptime
                if name == AVAudioSession.interruptionNotification {
                    let type = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
                    guard type != AVAudioSession.InterruptionType.ended.rawValue else { return }
                }
                Task { @MainActor [weak self] in
                    guard let self, self.busy, self.generation == token else { return }
                    guard startupFatal || time >= self.armedAt else { return }
                    self.finish(reason: reason, at: time)
                    if reason == .audioFailure {
                        self.errorMessage = "Audio configuration or media services changed. Start a new run."
                    }
                }
            })
        }
        add(AVAudioSession.interruptionNotification, object: nil, reason: .interrupted, startupFatal: true)
        add(AVAudioSession.routeChangeNotification, object: nil, reason: .routeChanged, startupFatal: false)
        add(.AVAudioEngineConfigurationChange, object: audio.engine, reason: .audioFailure, startupFatal: false)
        add(AVAudioSession.mediaServicesWereLostNotification, object: nil, reason: .audioFailure, startupFatal: true)
        add(AVAudioSession.mediaServicesWereResetNotification, object: nil, reason: .audioFailure, startupFatal: true)
    }

    private func removeObservers() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}
