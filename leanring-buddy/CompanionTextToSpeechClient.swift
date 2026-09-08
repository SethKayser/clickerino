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
        speechSynthesizer.speak(speechUtterance)
    }

    var isPlaying: Bool {
        speechSynthesizer.isSpeaking
    }

    func stopPlayback() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
}
