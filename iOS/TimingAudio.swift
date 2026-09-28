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
    private let voices = (0..<16).map { _ in AVAudioPlayerNode() }
    private var nextVoice = 0
    private var hit: AVAudioPCMBuffer?
    private var renderedRun: AVAudioPCMBuffer?
    private var graphReady = false
    private(set) var sampleRate = 0.0
    private(set) var voiceSteals = 0
    private var voiceEnds = Array(repeating: 0.0, count: 16)

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
        for node in [metronome] + voices {
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }
        graphReady = true
        hit = try sound(format: format, duration: 0.045, frequency: 180, amplitude: 0.22)
        setVolumes(metronome: metronomeVolume, rhythm: rhythmVolume)
        engine.prepare()
        try engine.start()
    }

    func setVolumes(metronome volume: Float, rhythm: Float) {
        metronome.volume = volume
        voices.forEach { $0.volume = rhythm }
    }

    /// Render before choosing the host start, so allocation cannot consume the pre-roll.
    func render(bpm: Int, barCount: Int = 16) throws {
        guard let format = hit?.format else { throw Failure.format }
        let interval = 60.0 / Double(bpm)
        let frameCount = Int(ceil(Double(barCount * 4) * interval * sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let samples = buffer.floatChannelData?[0] else { throw Failure.buffer }
        buffer.frameLength = buffer.frameCapacity
        samples.initialize(repeating: 0, count: frameCount)
        let normal = try sound(format: format, duration: 0.025, frequency: 1100, amplitude: 0.35)
        let accent = try sound(format: format, duration: 0.035, frequency: 1700, amplitude: 0.5)
        for beat in 0..<(barCount * 4) {
            let click = beat % 4 == 0 ? accent : normal
            let offset = Int((Double(beat) * interval * sampleRate).rounded())
            guard let source = click.floatChannelData?[0] else { throw Failure.buffer }
            for frame in 0..<min(Int(click.frameLength), frameCount - offset) {
                samples[offset + frame] = source[frame]
            }
        }
        renderedRun = buffer
    }

    func schedule(session: TimingSession) throws {
        guard engine.isRunning,
              engine.outputNode.outputFormat(forBus: 0).sampleRate == sampleRate,
              let buffer = renderedRun else { throw Failure.engineStopped }
        guard session.startTime - ProcessInfo.processInfo.systemUptime > 0.05 else {
            throw Failure.schedulingLate
        }
        // Buffer starts at player sample zero; play(at:) anchors that zero to host time.
        metronome.scheduleBuffer(buffer, at: nil, options: [])
        metronome.play(at: AVAudioTime(hostTime: AVAudioTime.hostTime(forSeconds: session.startTime)))
    }

    func playHit(now: Double) {
        guard engine.isRunning, let hit else { return }
        // Round-robin: the oldest of 16 voices is stolen, never a FIFO of pending hits.
        let index = nextVoice
        nextVoice = (nextVoice + 1) % voices.count
        if voiceEnds[index] > now { voiceSteals += 1 }
        let voice = voices[index]
        voice.stop()
        voice.scheduleBuffer(hit, at: nil, options: [])
        voice.play()
        voiceEnds[index] = now + Double(hit.frameLength) / sampleRate
    }

    func shutdown() {
        if graphReady {
            metronome.stop()
            voices.forEach { $0.stop() }
        }
        engine.stop()
        renderedRun = nil
        hit = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
