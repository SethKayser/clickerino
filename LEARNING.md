# Learn Clickerino by building it

This first milestone is deliberately small: one local request travels through
every important layer of a voice companion. Work through the files in the order
the request travels rather than trying to understand the whole project at once.

## The request journey

1. `GlobalPushToTalkShortcutMonitor.swift` detects Control+Option.
2. `BuddyDictationManager.swift` records microphone buffers.
3. `AppleSpeechTranscriptionProvider.swift` turns speech into text.
4. `CompanionScreenCaptureUtility.swift` captures and labels each display.
5. `OllamaVisionClient.swift` sends the text and screenshots to local Qwen.
6. `CompanionManager.swift` parses the model's optional `[POINT:...]` tag.
7. `OverlayWindow.swift` converts image coordinates into macOS coordinates.
8. `CompanionTextToSpeechClient.swift` speaks the clean response locally.

## What to learn first

### Exercise 1: Follow one request

Set breakpoints where the final transcript reaches `CompanionManager`, where
`OllamaVisionClient` creates its request, and where the response is parsed. Run
the app from Xcode, ask “what application am I looking at?”, and inspect the
text and screenshot labels at each breakpoint. Avoid printing image data.

You will learn Swift async tasks, callbacks and how state crosses service
boundaries.

### Exercise 2: Compare model sizes

Pull `qwen3-vl:2b` and change `OLLAMA_VISION_MODEL` in `Info.plist`. Ask the same
five screen questions with 2B and 4B. Record first-response time, whether the
answer is correct and whether the pointer lands on the intended element.

You will learn that model choice is an engineering tradeoff involving memory,
latency and reliability rather than a single quality score.

### Exercise 3: Make pointing structured

The inherited project asks the model to append a text tag such as
`[POINT:400,300:save button]`. Inspect `parsePointingCoordinates` in
`CompanionManager.swift`, then design a JSON response containing spoken text,
screen number, coordinates and label. Write parser tests before changing the
live request.

You will learn why structured model output is safer than regular expressions.

### Exercise 4: Add the next provider

Create a `CompanionVisionClient` protocol implemented by `OllamaVisionClient`.
Then implement Gemini behind the same protocol and add a Local/Cloud setting.
Do not silently fall back to cloud: the interface should indicate when a
screenshot will leave the Mac.

You will learn provider abstraction, configuration and privacy-aware routing.

## Debugging checklist

- `ollama list` should contain `qwen3-vl:4b`.
- `curl http://127.0.0.1:11434/api/tags` should return JSON.
- If speech never starts, inspect macOS Speech Recognition and Microphone
  permissions for the locally built app.
- If screenshots fail, inspect Screen Recording permission and restart the app
  after granting it.
- If the pointer is inaccurate, log image dimensions, display point dimensions
  and the selected screen number rather than guessing an offset.
- If Xcode reports a signing problem, choose your team and let Xcode create a
  development bundle identifier.

## Version-one boundaries

This milestone answers and points. It does not click controls, run autonomous
tasks, use Gemini, use the ChatGPT subscription through Codex, or persist long
term memory. Those should be separate milestones so each permission and failure
mode remains understandable.

Do not commit API keys, authentication tokens, `.dev.vars`, recordings or
captured screenshots. Keep paid fallbacks disabled until the interface has an
explicit spending limit and clearly shows which provider handled a request.
