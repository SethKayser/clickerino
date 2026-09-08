# Clicky feature comparison

This matrix records the current scope of the free local fork. The installed Clicky column comes from read-only inspection of version 1.0.48 (build 57). It describes observed product behavior and does not reproduce private source or artwork.

| Area | Installed Clicky 1.0.48 (57) | Public Clicky repository | Current fork | Local implementation or remaining work |
|---|---|---|---|---|
| Main shell | Notch-style panel with Home, Agents, Upgrade and Settings | Menu-bar companion with floating panel | Menu-bar panel with Home and Settings | Home/settings local shell is present; no subscription or fake Upgrade page |
| Voice states | Listening, thinking and speaking | Listening and processing animations | Idle, listening, processing and responding state machine | End-to-end live result remains pending after the current rebuild |
| Input | Voice and message composer | Push-to-talk | Control+Option push-to-talk and typed composer | Apple Speech and typed path use the local pipeline |
| Microphone | Device selection, test panel labelled “Receiving audio”, default/MacBook/Teams inputs, level display | Voice capture | Local audio settings view and live level display | Verify device behavior on the current signed build |
| Screen understanding | Hosted product behavior | Claude vision path | Ollama vision path with configurable model | `gemma3:4b` is the measured dependable default; Qwen remains selectable |
| Speech output | Configurable voice and speed | ElevenLabs through proxy | macOS system speech | Voice/speed controls are local settings; verify playback end to end |
| Cursor | Custom cursor options and visibility | Blue cursor and pointing animation | Existing overlay, color/visibility setting and point-tag parser | Coordinate accuracy is not yet dependable; malformed tags must remain text-only |
| Shortcuts | Configurable shortcuts | Control+Option | Control+Option plus stored local shortcut setting | General shortcut editor remains backlog |
| Integrations and skills | Integrations, skills and agent configuration | None in the public fork | None | Requires a real provider-backed design; do not add cosmetic tabs |
| History and progress | Task history and agent progress | Conversation state only | In-session conversation history and diagnostics | Persistent task history and progress events remain backlog |
| Files and images | Attachments | Screen images in vision request | ScreenCaptureKit screenshots | File/image attachment UI remains backlog |
| Privacy controls | Show in Dock and screen-recording visibility toggles | Basic permissions | Show in Dock, screen-capture mode and permission status | Verify stale permissions after signing changes |
| Camera | No camera settings or `NSCameraUsageDescription` observed | No camera feature identified | No camera feature | The inspected “camera” area is the microphone test panel |
| Billing | Upgrade and usage-oriented product surfaces | No billing surface | No billing or usage meter | Optional BYOK providers are planned, not implemented |

## Provider and agent backlog

The current provider boundary covers speech-to-text, vision/language reasoning and text-to-speech. The local path uses Apple Speech, Ollama and macOS system speech. Legacy Claude, OpenAI, AssemblyAI and ElevenLabs implementations remain for later routing and are not the default local path.

Optional BYOK providers should be added behind explicit settings and Keychain-backed secrets. This is planned work; no Keychain provider settings or Gemini, OpenAI, Anthropic, Grok or Groq routing should be presented as implemented.

Agents require a separate real execution lane: persisted tasks, permission boundaries, progress events, cancellation, file diff review, attachments and follow-up prompts. A tab without that backend would misrepresent the feature, so the current fork leaves agent execution as backlog.

## Supported agent integration and billing (verified 8 September 2026)

A future agent lane can launch an independently installed `codex app-server` over its default stdio JSONL transport. The supported protocol provides initialization, thread/turn creation, progress notifications, cancellation, and account login; schema generation should be pinned to the installed CLI version. This is a proposed integration, not a working backend in this fork. [Official app-server documentation](https://learn.chatgpt.com/docs/app-server).

Codex supports ChatGPT sign-in for subscription access and API-key sign-in for usage-based access. API-key requests are billed through the OpenAI Platform account at API rates; a ChatGPT subscription must not be represented as general OpenAI API credit. A future UI should show the active authentication method and applicable usage limits before starting agent work. [Official authentication documentation](https://learn.chatgpt.com/docs/auth).

Before exposing agent execution, implement persistent task IDs, scoped directories and approvals, progress and interruption events, attachment handling, diff review, and follow-up input. Keep provider keys in Keychain and never copy the installed official Clicky's bundled runtime or credentials.
