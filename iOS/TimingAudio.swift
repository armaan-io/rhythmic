import AVFoundation
import Foundation
import TimingCore

struct AudioSnapshot: Encodable {
    struct Output: Encodable {
        let name: String
        let type: String
    }
    let outputs: [Output]
    let bluetooth: Bool
    let sampleRate: Double
    let ioBufferDuration: Double
    let outputLatency: Double
    let engineOutputPresentationLatency: Double

    static func capture(engine: AVAudioEngine) -> AudioSnapshot {
        let session = AVAudioSession.sharedInstance()
        let ports = session.currentRoute.outputs
        return AudioSnapshot(
            outputs: ports.map { Output(name: $0.portName, type: $0.portType.rawValue) },
            bluetooth: ports.contains {
                [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains($0.portType)
            },
            sampleRate: session.sampleRate,
            ioBufferDuration: session.ioBufferDuration,
            outputLatency: session.outputLatency,
            engineOutputPresentationLatency: engine.outputNode.presentationLatency
        )
    }
}

/// All graph/control operations run on the main actor. No application render callbacks.
@MainActor
final class TimingAudio {
    let engine = AVAudioEngine()
    private let metronome = AVAudioPlayerNode()
    private let demonstration = AVAudioPlayerNode()
    private let voices = (0..<16).map { _ in AVAudioPlayerNode() }
    private var nextVoice = 0
    private var hit: AVAudioPCMBuffer?
    private var renderedRun: AVAudioPCMBuffer?
    private var renderedDemonstration: AVAudioPCMBuffer?
    private var rhythmLevel: Float = 0.7
    private var graphReady = false
    private(set) var sampleRate = 0.0
    private(set) var voiceSteals = 0
    private var voiceEnds = Array(repeating: 0.0, count: 16)
    private var voiceTokens: [UUID?] = Array(repeating: nil, count: 16)

    enum Failure: LocalizedError {
        case format, buffer, engineStopped, schedulingLate
        var errorDescription: String? {
            switch self {
            case .format: return "The audio route has no supported output format."
            case .buffer: return "Unable to allocate the bounded audio buffer."
            case .engineStopped: return "The audio engine stopped or changed format during startup. Try Start again."
            case .schedulingLate: return "Audio scheduling missed its preparation window. Try Start again."
            }
        }
    }

    func prepare(metronomeVolume: Float, rhythmVolume: Float) throws {
        guard !graphReady else { throw Failure.format }
        let session = AVAudioSession.sharedInstance()
        // Playback already supports A2DP routes; the explicit A2DP option is for
        // play-and-record sessions. Do not enable an input route or microphone.
        try session.setCategory(.playback, mode: .default)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        guard sampleRate.isFinite, (8_000...192_000).contains(sampleRate),
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        else { throw Failure.format }
        for node in [metronome, demonstration] + voices {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        graphReady = true
        hit = try snare(format: format)
        setVolumes(metronome: metronomeVolume, rhythm: rhythmVolume)
        engine.prepare()
        try engine.start()
    }

    func setVolumes(metronome volume: Float, rhythm: Float) {
        metronome.volume = volume.isFinite ? min(1, max(0, volume)) : 0
        rhythmLevel = rhythm.isFinite ? min(1, max(0, rhythm)) : 0
        updateRhythmGain()
    }

    var isHealthy: Bool {
        engine.isRunning && engine.outputNode.outputFormat(forBus: 0).sampleRate == sampleRate
    }

    /// Render before choosing the host start, so allocation cannot consume the pre-roll.
    func render(bpm: Int, barCount: Int = 16) throws {
        let session = try TimingSession(bpm: bpm, startTime: 0, barCount: barCount)
        try renderMetronome(session: session)
        renderedDemonstration = nil
    }

    /// Absolute plan timestamps become offsets from the first planned click.
    /// A zero-anchored template can be rendered, then scheduled with a fresh host start.
    func render(plan: PracticeAudioPlan) throws {
        try renderMetronome(session: plan.metronome)
        renderedDemonstration = nil
        guard !plan.demonstrationOnsets.isEmpty, let hit,
              let source = hit.floatChannelData?[0] else { return }
        let buffer = try emptyBuffer(duration: plan.metronome.endTime - plan.metronome.startTime,
                                     format: hit.format)
        guard let samples = buffer.floatChannelData?[0] else { throw Failure.buffer }
        let frameCount = Int(buffer.frameLength)
        for onset in plan.demonstrationOnsets {
            let relative = onset - plan.metronome.startTime
            guard relative.isFinite, relative >= 0,
                  relative < plan.metronome.endTime - plan.metronome.startTime else { throw Failure.buffer }
            let offset = Int((relative * sampleRate).rounded())
            for frame in 0..<max(0, min(Int(hit.frameLength), frameCount - offset)) {
                samples[offset + frame] += source[frame]
            }
        }
        // Catalog eighth notes cannot overlap this 80 ms sample even at 240 BPM.
        renderedDemonstration = buffer
        updateRhythmGain()
    }

    private func renderMetronome(session: TimingSession) throws {
        guard let format = hit?.format else { throw Failure.format }
        let buffer = try emptyBuffer(duration: session.endTime - session.startTime, format: format)
        guard let samples = buffer.floatChannelData?[0] else { throw Failure.buffer }
        let frameCount = Int(buffer.frameLength)
        let normal = try sound(format: format, duration: 0.025, frequency: 1100, amplitude: 0.35)
        let accent = try sound(format: format, duration: 0.035, frequency: 1700, amplitude: 0.5)
        for beat in session.beats {
            let click = beat.isAccent ? accent : normal
            let offset = Int(((beat.scheduledTime - session.startTime) * sampleRate).rounded())
            guard let source = click.floatChannelData?[0] else { throw Failure.buffer }
            for frame in 0..<min(Int(click.frameLength), frameCount - offset) {
                samples[offset + frame] = source[frame]
            }
        }
        renderedRun = buffer
    }

    private func emptyBuffer(duration: Double, format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        guard duration.isFinite, duration > 0, duration <= 128 else { throw Failure.buffer }
        let frameCount = Int(ceil(duration * sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let samples = buffer.floatChannelData?[0] else { throw Failure.buffer }
        buffer.frameLength = buffer.frameCapacity
        samples.initialize(repeating: 0, count: frameCount)
        return buffer
    }

    func schedule(session: TimingSession) throws {
        guard isHealthy,
              let buffer = renderedRun else { throw Failure.engineStopped }
        guard session.startTime - ProcessInfo.processInfo.systemUptime > 0.05 else {
            throw Failure.schedulingLate
        }
        // Buffer starts at player sample zero; play(at:) anchors that zero to host time.
        metronome.stop()
        demonstration.stop()
        voices.forEach { $0.stop() }
        voiceEnds = Array(repeating: 0, count: voices.count)
        voiceTokens = Array(repeating: nil, count: voices.count)
        updateRhythmGain()
        metronome.scheduleBuffer(buffer, at: nil, options: [])
        if let demo = renderedDemonstration {
            demonstration.scheduleBuffer(demo, at: nil, options: [])
        }
        let start = AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: session.startTime))
        // Recheck after buffer scheduling, before either player is started.
        guard session.startTime - ProcessInfo.processInfo.systemUptime > 0.05 else {
            throw Failure.schedulingLate
        }
        metronome.play(at: start)
        if renderedDemonstration != nil { demonstration.play(at: start) }
    }

    func playHit(now: Double) {
        guard isHealthy, now.isFinite, let hit else { return }
        // Round-robin: the oldest of 16 voices is stolen, never a FIFO of pending hits.
        let index = nextVoice
        nextVoice = (nextVoice + 1) % voices.count
        if voiceEnds[index] > now { voiceSteals += 1 }
        let voice = voices[index]
        voice.stop()
        voiceEnds[index] = now + Double(hit.frameLength) / sampleRate
        let token = UUID()
        voiceTokens[index] = token
        updateRhythmGain()
        voice.scheduleBuffer(hit, at: nil, options: [], completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.voiceTokens[index] == token else { return }
                self.voiceTokens[index] = nil
                // Do not raise the gain of tails as voices finish. The next hit
                // or slider change recalculates it using confirmed completions.
            }
        }
        voice.play()
    }

    private func updateRhythmGain() {
        // Bound the summed snare peak to 0.45, leaving the original 0.5 accent
        // headroom even for 16 coincident voices at maximum slider settings.
        // Completion, rather than an estimated host end, includes output buffering.
        let active = voiceTokens.compactMap { $0 }.count + (renderedDemonstration == nil ? 0 : 1)
        let level = rhythmLevel / Float(max(1, active))
        demonstration.volume = level
        voices.forEach { $0.volume = level }
    }

    /// Silence immediately without deactivating the route. Practice can drain
    /// pending touch deliveries before final teardown changes the audio session.
    func stopPlayback() {
        voiceTokens = Array(repeating: nil, count: voices.count)
        if graphReady {
            metronome.stop()
            demonstration.stop()
            voices.forEach { $0.stop() }
        }
        engine.stop()
    }

    func shutdown() {
        stopPlayback()
        renderedRun = nil
        renderedDemonstration = nil
        hit = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func snare(format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let buffer = try emptyBuffer(duration: 0.080, format: format)
        guard let samples = buffer.floatChannelData?[0] else { throw Failure.buffer }
        let count = Int(buffer.frameLength)
        var random: UInt32 = 0x53A9_17E5
        var previous = 0.0
        for frame in 0..<count {
            random = 1_664_525 &* random &+ 1_013_904_223
            let noise = Double(random) / Double(UInt32.max) * 2 - 1
            let brightNoise = (noise - previous) * 0.5
            previous = noise
            let t = Double(frame) / sampleRate
            let attack = min(1, t / 0.0003)
            let release = max(0, 1 - Double(frame) / Double(count - 1))
            let transient = brightNoise * exp(-t * 65)
            let body = sin(2 * .pi * 210 * t) * exp(-t * 48)
            samples[frame] = Float(0.45 * attack * release * (0.78 * transient + 0.22 * body))
        }
        return buffer
    }

    private func sound(format: AVAudioFormat, duration: Double, frequency: Double,
                       amplitude: Double) throws -> AVAudioPCMBuffer {
        let count = Int(duration * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let samples = buffer.floatChannelData?[0] else { throw Failure.buffer }
        buffer.frameLength = buffer.frameCapacity
        for frame in 0..<count {
            let t = Double(frame) / sampleRate
            let attack = min(1, t / 0.001)
            let release = max(0, 1 - Double(frame) / Double(count))
            samples[frame] = Float(amplitude * attack * release * exp(-t * 90) * sin(2 * .pi * frequency * t))
        }
        return buffer
    }
}
