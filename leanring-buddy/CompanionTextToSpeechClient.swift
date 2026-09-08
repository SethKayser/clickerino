//
//  CompanionTextToSpeechClient.swift
//  leanring-buddy
//
//  Defines the companion's text-to-speech boundary and provides a free,
//  offline implementation using the speech voices built into macOS.
//

import AVFoundation
import Foundation

@MainActor
protocol CompanionTextToSpeechClient {
    func speakText(_ text: String) async throws
    var isPlaying: Bool { get }
    func stopPlayback()
}

@MainActor
final class MacOSSystemTextToSpeechClient: CompanionTextToSpeechClient {
    private let speechSynthesizer = AVSpeechSynthesizer()

    func speakText(_ text: String) async throws {
        try Task.checkCancellation()

        let textToSpeak = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSpeak.isEmpty else { return }

        stopPlayback()

        let speechUtterance = AVSpeechUtterance(string: textToSpeak)
        let voiceIdentifier = UserDefaults.standard.string(forKey: "localSpeechVoiceIdentifier") ?? ""
        if !voiceIdentifier.isEmpty {
            speechUtterance.voice = AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        }
        if let speechRate = UserDefaults.standard.object(forKey: "localSpeechRate") as? Double {
            speechUtterance.rate = Float(min(0.65, max(0.3, speechRate)))
        }
        speechSynthesizer.speak(speechUtterance)
    }

    var isPlaying: Bool {
        speechSynthesizer.isSpeaking
    }

    func stopPlayback() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}
