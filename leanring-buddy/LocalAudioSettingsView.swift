import SwiftUI
import Combine
import AVFoundation
import CoreAudio
import AudioToolbox

extension Notification.Name {
    static let clickyStopMicrophoneTest = Notification.Name("clickyStopMicrophoneTest")
    static let clickyVoiceCaptureWillStart = Notification.Name("clickyVoiceCaptureWillStart")
}

/// Uses the same saved input for the test meter and push-to-talk capture.
enum LocalMicrophoneSelection {
    static func apply(to inputNode: AVAudioInputNode) throws {
        let selectedUID = UserDefaults.standard.string(forKey: "localMicrophoneUID") ?? ""
        guard !selectedUID.isEmpty else { return }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var byteCount: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &byteCount) == noErr else { return }
        var devices = [AudioDeviceID](repeating: 0, count: Int(byteCount) / MemoryLayout<AudioDeviceID>.size)
        let status = devices.withUnsafeMutableBytes { AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &byteCount, $0.baseAddress!) }
        guard status == noErr else { return }
        for var device in devices {
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            var uidAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            let uidStatus = withUnsafeMutablePointer(to: &uid) { AudioObjectGetPropertyData(device, &uidAddress, 0, nil, &uidSize, $0) }
            if uidStatus == noErr && uid as String == selectedUID, let audioUnit = inputNode.audioUnit {
                let result = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, UInt32(MemoryLayout<AudioDeviceID>.size))
                guard result == noErr else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: [NSLocalizedDescriptionKey: "Could not select microphone."]) }
                return
            }
        }
        throw NSError(domain: "LocalMicrophone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Selected microphone is disconnected. Choose System Default."])
    }
}

@MainActor
final class LocalMicrophoneTest: ObservableObject {
    @Published var isTesting = false
    @Published var level: Double = 0
    @Published var errorMessage: String?
    private var audioEngine: AVAudioEngine?

    func start() {
        stop()
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            errorMessage = "Grant microphone access in Permissions first."
            return
        }
        do {
            let engine = AVAudioEngine()
            let input = engine.inputNode
            try LocalMicrophoneSelection.apply(to: input)
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw NSError(domain: "LocalMicrophone", code: 2, userInfo: [NSLocalizedDescriptionKey: "Microphone has no audio input."]) }
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
                var total: Float = 0
                for index in 0..<Int(buffer.frameLength) { total += samples[index] * samples[index] }
                let amplitude = min(1, Double(sqrt(total / Float(buffer.frameLength))) * 8)
                Task { @MainActor in self?.level = amplitude }
            }
            audioEngine = engine
            engine.prepare()
            try engine.start()
            errorMessage = nil
            isTesting = true
        } catch { stop(); errorMessage = error.localizedDescription }
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        isTesting = false
        level = 0
    }
}

struct LocalAudioSettingsView: View {
    @AppStorage("localMicrophoneUID") private var microphoneUID = ""
    @AppStorage("localSpeechVoiceIdentifier") private var voiceIdentifier = ""
    @AppStorage("localSpeechRate") private var speechRate = Double(AVSpeechUtteranceDefaultSpeechRate)
    @StateObject private var microphoneTest = LocalMicrophoneTest()
    private var microphones: [AVCaptureDevice] { AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified).devices }
    private var voices: [AVSpeechSynthesisVoice] { AVSpeechSynthesisVoice.speechVoices().sorted { $0.name < $1.name } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audio").font(.headline)
            Picker("Microphone", selection: $microphoneUID) {
                Text("System Default").tag("")
                ForEach(microphones, id: \.uniqueID) { Text($0.localizedName).tag($0.uniqueID) }
            }
            .disabled(microphoneTest.isTesting)
            Button(microphoneTest.isTesting ? "Stop microphone test" : "Test microphone") {
                if microphoneTest.isTesting { microphoneTest.stop() } else { microphoneTest.start() }
            }
            .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            ProgressView(value: microphoneTest.level).tint(.green)
            Text(microphoneTest.isTesting ? "Listening locally • no audio is saved or sent" : "Test the selected input before talking.")
                .font(.caption).foregroundStyle(.secondary)
            if let error = microphoneTest.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
            Picker("Voice", selection: $voiceIdentifier) {
                Text("System Default").tag("")
                ForEach(voices, id: \.identifier) { Text("\($0.name) (\($0.language))").tag($0.identifier) }
            }
            HStack {
                Text("Speech speed")
                Slider(value: $speechRate, in: 0.3...0.65)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clickyVoiceCaptureWillStart)) { _ in microphoneTest.stop() }
        .onReceive(NotificationCenter.default.publisher(for: .clickyStopMicrophoneTest)) { _ in microphoneTest.stop() }
        .onDisappear { microphoneTest.stop() }
    }
}
