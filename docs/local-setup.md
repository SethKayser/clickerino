# Local setup and learning path

Clickerino is a menu-bar macOS app. The local path keeps screen and voice processing on the Mac: Apple Speech handles transcription, Ollama handles screen understanding, and macOS system speech reads responses. The configured default model is `gemma3:4b`; see [model-benchmarks.md](model-benchmarks.md) for the controlled comparison with `qwen3-vl:4b`.

## Run from Xcode

1. Install and start Ollama, then confirm the configured model is available with `ollama list`. The app reads `OLLAMA_VISION_MODEL` and `OLLAMA_API_URL` from `leanring-buddy/Info.plist`.
2. Open `leanring-buddy.xcodeproj` in Xcode.
3. Select the `leanring-buddy` scheme, use Sign to Run Locally (or your own valid signing team), and run with Cmd+R.
4. Grant Microphone, Speech Recognition, Accessibility, Screen Recording and Screen Content permissions when macOS asks. A signing identity or bundle change can make macOS treat the build as a new client and require the permissions again.
5. Use the menu-bar icon. Hold Control+Option, speak, and release; the typed composer on Home exercises the same screenshot-and-response path without audio.

Do not use terminal `xcodebuild` for this project. The project policy reserves builds for Xcode so signing and TCC state can be observed together. Testing showed that a rebuilt ad-hoc app received a new code hash, so macOS treated it as a new client and denied the old permission record; the hash change, rather than the build command alone, was the observed cause of stale TCC records.

## Useful source map

- `CompanionManager.swift` coordinates permissions, state, screenshots, model requests, cancellation and speech.
- `BuddyDictationManager.swift` captures push-to-talk audio and publishes transcript/audio-level state.
- `AppleSpeechTranscriptionProvider.swift` supplies the local transcription implementation.
- `CompanionScreenCaptureUtility.swift` captures labelled displays through ScreenCaptureKit.
- `OllamaVisionClient.swift` sends screenshots to Ollama and validates non-empty responses, including `done_reason` diagnostics.
- `CompanionTextToSpeechClient.swift` provides macOS system speech.
- `CompanionPanelView.swift` provides Home/Settings, typed input, permissions, local model and diagnostics controls.
- `OverlayWindow.swift` displays the cursor, waveform, response bubble and optional pointing animation.

## Logs and diagnosis

Run the signed app from Xcode so its console remains visible. Reproduce one interaction, then inspect the stage at which it stops: shortcut, listening, transcript, screen capture, Ollama response, speech or idle reset. The Settings diagnostics card retains the last pipeline error, response duration and Ollama completion reason. An HTTP 200 response is not sufficient evidence of success; the decoded answer must be non-empty.

If the app does not respond, check that the official Clicky app is closed so it cannot own Control+Option, check Ollama is running, and review each permission in System Settings → Privacy & Security. Avoid changing permissions or signing identities while comparing runs because macOS may reset the client’s TCC record.

## Small learning exercises

Trace `submitTypedPrompt` from `CompanionPanelView` into `CompanionManager`, then identify where the screenshot is attached to the Ollama request. As a small UI exercise, change one `DS` color in `CompanionPanelView` and run from Xcode to see the menu-bar panel update. For model experiments, choose the model in Settings (saved selection overrides `OLLAMA_VISION_MODEL`), keep the screenshot and question fixed, and record timing and malformed output in the benchmark document.

## Verification record — 8 September 2026

- The signed app built and opened through Xcode with Home/Settings and audio/settings controls visible.
- Xcode executed all 14 unit tests successfully. The UI-test runner timed out enabling macOS automation mode, so the overall test action reports failure; do not interpret that as a passing UI suite.
- A final task-reference cleanup and bundle-model fallback correction were made after that run; those changes need another Xcode build/test before treating the latest source as fully verified.
- The running fork reported stale permission grants. TCC logs showed a stored signing hash different from the rebuilt app. Only this fork's Microphone, Speech Recognition, Accessibility and Screen Recording records were reset after user authorization; permission restoration remains pending.
- The Mac locked during testing. Final typed, microphone, voice, playback, pointing and cancellation checks on the latest signed build are pending unlock. The model benchmark verifies direct local inference, not the complete application path.

The current microphone test is transient: it stops on panel close, on leaving Settings, and when dictation begins. No microphone-test recording is saved or sent to Ollama.
