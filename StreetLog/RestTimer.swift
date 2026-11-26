import AVFoundation
import SwiftUI

/// Countdown between sets. The chosen duration and the auto-start switch are remembered.
@MainActor
final class RestTimer: ObservableObject {
    static let shared = RestTimer()
    static let presets = [60, 90, 120, 180, 300]

    @Published private(set) var endsAt: Date?
    @Published private(set) var duration: TimeInterval = 120
    @Published private(set) var defaultSeconds: Int
    @Published private(set) var autoStart: Bool
    @Published private(set) var finishedAt: Date?
    @Published private(set) var now = Date()

    private var ticker: Timer?
    private var finisher: Timer?
    /// Kept alive until the tones finish playing.
    private var players: [AVAudioPlayer] = []

    private init() {
        let defaults = UserDefaults.standard
        defaultSeconds = defaults.object(forKey: "rest.default") as? Int ?? 120
        autoStart = (defaults.object(forKey: "rest.auto") as? Bool) ?? true
    }

    var remaining: TimeInterval {
        guard let endsAt else { return 0 }
        return max(0, endsAt.timeIntervalSince(now))
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    func start(seconds: Int? = nil) {
        let value = max(1, seconds ?? defaultSeconds)
        defaultSeconds = value
        UserDefaults.standard.set(value, forKey: "rest.default")
        duration = TimeInterval(value)
        endsAt = Date().addingTimeInterval(duration)
        finishedAt = nil
        arm()
    }

    /// Called after a set is logged.
    func autoStartIfEnabled() {
        if autoStart { start() }
    }

    func add(_ seconds: Int) {
        guard let endsAt else { return }
        let next = max(Date().addingTimeInterval(1), endsAt.addingTimeInterval(TimeInterval(seconds)))
        duration = max(1, duration + TimeInterval(seconds))
        self.endsAt = next
        arm()
    }

    func stop() {
        finisher?.invalidate()
        ticker?.invalidate()
        ticker = nil
        endsAt = nil
        finishedAt = nil
    }

    func setAutoStart(_ on: Bool) {
        autoStart = on
        UserDefaults.standard.set(on, forKey: "rest.auto")
    }

    static func format(_ seconds: TimeInterval) -> String {
        let whole = Int(ceil(max(0, seconds)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    static func caption(_ seconds: Int) -> String {
        switch seconds {
        case ...90: "объём, пампинг"
        case ...180: "рабочие подходы"
        default: "тяжёлые, одиночки"
        }
    }

    private func arm() {
        finisher?.invalidate()
        if ticker == nil {
            let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
                MainActor.assumeIsolated { RestTimer.shared.now = Date() }
            }
            RunLoop.main.add(timer, forMode: .common)
            ticker = timer
        }
        guard let endsAt else { return }
        let timer = Timer(timeInterval: max(0.05, endsAt.timeIntervalSinceNow), repeats: false) { _ in
            MainActor.assumeIsolated { RestTimer.shared.finish() }
        }
        RunLoop.main.add(timer, forMode: .common)
        finisher = timer
    }

    private func finish() {
        endsAt = nil
        finishedAt = Date()
        ticker?.invalidate()
        ticker = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        playBeeps()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            if let finishedAt, Date().timeIntervalSince(finishedAt) >= 5.5 {
                self.finishedAt = nil
            }
        }
    }

    private func playBeeps() {
        for index in 0..<3 {
            let frequency = index == 2 ? 1320.0 : 880.0
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(index * 350))
                self.tone(frequency: frequency)
            }
        }
    }

    private func tone(frequency: Double) {
        let rate = 44100.0
        let length = Int(rate * 0.22)
        var samples = [Float](repeating: 0, count: length)
        for i in 0..<length {
            let time = Double(i) / rate
            let attack = min(1, Double(i) / 300)
            let release = min(1, Double(length - i) / 1200)
            samples[i] = Float(sin(2 * .pi * frequency * time) * 0.45 * attack * release)
        }
        guard let player = Self.wavPlayer(samples: samples, rate: Int(rate)) else { return }
        players.removeAll { !$0.isPlaying }
        players.append(player)
        player.play()
    }

    /// A tiny in-memory WAV, so the beep needs no bundled sound file.
    private static func wavPlayer(samples: [Float], rate: Int) -> AVAudioPlayer? {
        let dataSize = samples.count * 2
        var data = Data()
        func append(_ value: UInt32) { var v = value.littleEndian; data.append(Data(bytes: &v, count: 4)) }
        func append16(_ value: UInt16) { var v = value.littleEndian; data.append(Data(bytes: &v, count: 2)) }
        data.append(contentsOf: "RIFF".utf8); append(UInt32(36 + dataSize))
        data.append(contentsOf: "WAVEfmt ".utf8); append(16); append16(1); append16(1)
        append(UInt32(rate)); append(UInt32(rate * 2)); append16(2); append16(16)
        data.append(contentsOf: "data".utf8); append(UInt32(dataSize))
        for sample in samples {
            let clamped = max(-1, min(1, sample))
            append16(UInt16(bitPattern: Int16(clamped * 32767)))
        }
        let player = try? AVAudioPlayer(data: data)
        player?.prepareToPlay()
        return player
    }
}
