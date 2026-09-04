#if os(macOS)
import AppKit
import AVFoundation
import Foundation
import CodexBellCore

@MainActor
final class AudioAnnouncer: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var speechContinuation: CheckedContinuation<Void, Never>?
    private lazy var chime: NSSound? = {
        if let custom = Bundle.main.url(forResource: "CodexBellChime", withExtension: "wav"),
           let sound = NSSound(contentsOf: custom, byReference: false) {
            return sound
        }
        return NSSound(named: NSSound.Name("Glass")) ?? NSSound(contentsOf: URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff"), byReference: true)
    }()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func announce(_ announcement: Announcement, volume: Double, language: AppLanguage) async {
        let level = Float(min(max(volume, 0), 1))
        chime?.stop()
        chime?.volume = level
        chime?.play()
        try? await Task.sleep(for: .milliseconds(620))

        let utterance = AVSpeechUtterance(string: LocalizedCopy(language: language).speech(for: announcement))
        utterance.volume = level
        utterance.rate = 0.48
        if language == .zhHans {
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        await withCheckedContinuation { continuation in
            speechContinuation = continuation
            synthesizer.speak(utterance)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.finishSpeech()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.finishSpeech()
        }
    }

    private func finishSpeech() {
        speechContinuation?.resume()
        speechContinuation = nil
    }
}
#endif
