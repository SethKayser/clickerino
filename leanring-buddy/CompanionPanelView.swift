//
//  CompanionPanelView.swift
//  leanring-buddy
//
//  The SwiftUI content hosted inside the menu bar panel. Shows the companion
//  voice status, push-to-talk shortcut, and quick settings. Designed to feel
//  like Loom's recording panel — dark, rounded, minimal, and special.
//

import AVFoundation
import Speech
import SwiftUI

struct CompanionPanelView: View {
    @ObservedObject var companionManager: CompanionManager
    @State private var selectedTab: PanelTab = .home
    @State private var draftText = ""
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("localPushToTalkShortcut") private var pushToTalkShortcut = "controlOption"
    @AppStorage("localCursorColor") private var cursorColor = "blue"

    private enum PanelTab: String, CaseIterable {
        case home = "Home"
        case settings = "Settings"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            panelHeader
            tabPicker
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

            Divider().background(DS.Colors.borderSubtle).padding(.horizontal, 16)

            ScrollView(.vertical, showsIndicators: false) {
                if selectedTab == .home {
                    homeContent
                } else {
                    settingsContent
                }
            }
            .frame(maxHeight: 560)

            footerSection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 360, height: 560)
        .background(panelBackground)
        .task {
            await companionManager.refreshOllamaStatus()
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(PanelTab.allCases, id: \.self) { tab in
                Button(tab.rawValue) { selectedTab = tab }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(selectedTab == tab ? DS.Colors.textPrimary : DS.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 7).fill(selectedTab == tab ? DS.Colors.surface3 : .clear))
                    .pointerCursor()
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(DS.Colors.surface1))
    }

    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            statusCard
            composer

            if let error = companionManager.lastPipelineError {
                pipelineMessage(error, isError: true)
            } else if let response = companionManager.lastResponseText, !response.isEmpty {
                responsePreview(response)
            }

            if !companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
                startButton
            } else if !companionManager.allPermissionsGranted {
                setupPrompt
            }
        }
        .padding(16)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !companionManager.allPermissionsGranted { settingsSection }
            LocalAudioSettingsView()
            settingsCard
            diagnosticsCard
        }
        .padding(16)
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(statusDotColor.opacity(0.18)).frame(width: 38, height: 38)
                Image(systemName: statusSymbol).font(.system(size: 16, weight: .semibold)).foregroundColor(statusDotColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(statusText).font(.system(size: 15, weight: .semibold)).foregroundColor(DS.Colors.textPrimary)
                Text(statusDetail).font(.system(size: 11)).foregroundColor(DS.Colors.textTertiary)
            }
            Spacer()
            if companionManager.isResponseInFlight {
                Button("Stop") { companionManager.cancelResponse() }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.Colors.warning).pointerCursor()
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(DS.Colors.surface1))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Colors.borderSubtle, lineWidth: 0.8))
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Ask Clicky anything…", text: $draftText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundColor(DS.Colors.textPrimary)
                .onSubmit { submitDraft() }
            Button(action: submitDraft) {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 22)).foregroundColor(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? DS.Colors.textTertiary : DS.Colors.accent)
            }
            .buttonStyle(.plain).pointerCursor()
            .disabled(draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 11).fill(DS.Colors.surface2))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(DS.Colors.borderStrong, lineWidth: 0.8))
    }

    private func submitDraft() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        companionManager.submitTypedPrompt(text)
        draftText = ""
    }

    private func pipelineMessage(_ message: String, isError: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: isError ? "exclamationmark.triangle" : "checkmark.circle")
            Text(message)
            Spacer()
        }
        .font(.system(size: 11, weight: .medium)).foregroundColor(isError ? DS.Colors.warning : DS.Colors.success)
    }

    private func responsePreview(_ response: String) -> some View {
        Text(response.replacingOccurrences(of: "[POINT:none]", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
            .font(.system(size: 12))
            .foregroundColor(DS.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .lineLimit(4)
    }

    private var setupPrompt: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Finish setup to use screen-aware help")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(DS.Colors.textSecondary)
            Text("Open Settings and grant the remaining permissions. The local model only receives a screenshot when you ask a question.")
                .font(.system(size: 11)).foregroundColor(DS.Colors.textTertiary).fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") { selectedTab = .settings }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold)).foregroundColor(DS.Colors.blue400).pointerCursor()
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LOCAL COMPANION")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textTertiary)
            settingToggleRow(icon: "cursorarrow", title: "Show Clicky cursor", subtitle: "Keep the companion visible while you work", isOn: Binding(get: { companionManager.isClickyCursorEnabled }, set: { companionManager.setClickyCursorEnabled($0) }))
            settingToggleRow(icon: "dock.rectangle", title: "Show in Dock", subtitle: "Also keep Clicky in the Dock", isOn: Binding(get: { showInDock }, set: { value in showInDock = value; NSApp.setActivationPolicy(value ? .regular : .accessory) }))
            PickerRow(icon: "keyboard", title: "Push to talk") {
                Picker("Push to talk", selection: $pushToTalkShortcut) {
                    ForEach(BuddyPushToTalkShortcut.ShortcutOption.allCases, id: \.rawValue) { option in
                        Text(option.displayText).tag(option.rawValue)
                    }
                }
                .labelsHidden().frame(width: 150)
            }
            PickerRow(icon: "cursorarrow.rays", title: "Cursor colour") {
                Picker("Cursor colour", selection: $cursorColor) {
                    Text("Blue").tag("blue"); Text("Green").tag("green"); Text("Purple").tag("purple"); Text("Orange").tag("orange")
                }
                .labelsHidden().frame(width: 110)
            }
            if companionManager.availableVisionModels.isEmpty {
                HStack { Image(systemName: "brain").frame(width: 18).foregroundColor(DS.Colors.textTertiary); Text("Vision model").font(.system(size: 13, weight: .medium)).foregroundColor(DS.Colors.textSecondary); Spacer(); Text(companionManager.isOllamaAvailable ? "No models found" : "Ollama unavailable").font(.system(size: 11, weight: .medium)).foregroundColor(DS.Colors.warning) }
            } else {
                PickerRow(icon: "brain", title: "Vision model") {
                    Picker("Vision model", selection: $companionManager.selectedVisionModel) {
                        ForEach(companionManager.availableVisionModels, id: \.self) { model in Text(model).tag(model) }
                    }
                    .labelsHidden().frame(width: 150)
                }
            }
            HStack {
                Spacer()
                Button {
                    Task { await companionManager.refreshOllamaStatus() }
                } label: {
                    Label("Refresh local models", systemImage: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(DS.Colors.blue400)
                .pointerCursor()
            }
            PickerRow(icon: "rectangle.on.rectangle", title: "Screen capture") {
                Picker("Screen capture", selection: $companionManager.screenCaptureMode) {
                    ForEach(CompanionScreenCaptureMode.allCases) { mode in
                        Text(mode == .cursorScreen ? "Cursor screen" : mode == .allScreens ? "All screens" : "No screenshot").tag(mode)
                    }
                }
                .labelsHidden().frame(width: 150)
            }
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(DS.Colors.surface1)).overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Colors.borderSubtle, lineWidth: 0.8))
    }

    private func settingToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 9) { Image(systemName: icon).frame(width: 18).foregroundColor(DS.Colors.textTertiary); VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(DS.Colors.textSecondary); Text(subtitle).font(.system(size: 10)).foregroundColor(DS.Colors.textTertiary) }; Spacer(); Toggle("", isOn: isOn).labelsHidden().toggleStyle(.switch).tint(DS.Colors.accent).scaleEffect(0.8) }
    }

    private struct PickerRow<PickerContent: View>: View {
        let icon: String
        let title: String
        @ViewBuilder let pickerContent: () -> PickerContent

        var body: some View {
            HStack { Image(systemName: icon).frame(width: 18).foregroundColor(DS.Colors.textTertiary); Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(DS.Colors.textSecondary); Spacer(); pickerContent() }
        }
    }

    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DIAGNOSTICS")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textTertiary)
            diagnosticRow("Microphone", companionManager.hasMicrophonePermission ? "Ready" : "Permission needed", companionManager.hasMicrophonePermission)
            diagnosticRow("Speech recognition", companionManager.hasSpeechRecognitionPermission ? "Ready" : "Permission needed", companionManager.hasSpeechRecognitionPermission)
            diagnosticRow("Screen capture", companionManager.hasScreenRecordingPermission && companionManager.hasScreenContentPermission ? "Ready" : "Permission needed", companionManager.hasScreenRecordingPermission && companionManager.hasScreenContentPermission)
            if let duration = companionManager.lastResponseDuration {
                Text("Last local response · \(String(format: "%.1f", duration))s")
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colors.textTertiary)
                    .padding(.top, 2)
            }
            if !companionManager.diagnosticLog.isEmpty {
                DisclosureGroup("Recent diagnostics") {
                    Text(companionManager.diagnosticLog.joined(separator: "\n"))
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let doneReason = companionManager.lastDoneReason {
                Text("Model completion · \(doneReason)")
                    .font(.system(size: 10))
                    .foregroundColor(DS.Colors.textTertiary)
            }
        }
        .padding(12).background(RoundedRectangle(cornerRadius: 12).fill(DS.Colors.surface1)).overlay(RoundedRectangle(cornerRadius: 12).stroke(DS.Colors.borderSubtle, lineWidth: 0.8))
    }

    private func diagnosticRow(_ title: String, _ detail: String, _ ready: Bool) -> some View { HStack { Text(title).font(.system(size: 12)).foregroundColor(DS.Colors.textSecondary); Spacer(); Text(detail).font(.system(size: 11, weight: .medium)).foregroundColor(ready ? DS.Colors.success : DS.Colors.warning) } }

    // MARK: - Header

    private var panelHeader: some View {
        HStack {
            HStack(spacing: 8) {
                // Animated status dot
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusDotColor.opacity(0.6), radius: 4)

                Text("Clicky")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.textPrimary)
            }

            Spacer()

            Text(statusText)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textTertiary)

            Button(action: {
                NotificationCenter.default.post(name: .clickyDismissPanel, object: nil)
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(DS.Colors.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Permissions Copy

    @ViewBuilder
    private var permissionsCopySection: some View {
        if companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
            Text("Hold Control+Option to talk.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if companionManager.allPermissionsGranted {
            Text("You're all set. Hit Start to meet Clicky.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if companionManager.hasCompletedOnboarding {
            // Permissions were revoked after onboarding — tell user to re-grant
            VStack(alignment: .leading, spacing: 6) {
                Text("Permissions needed")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DS.Colors.textSecondary)

                Text("Some permissions were revoked. Grant each permission below to keep using Clicky.")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome to Clickerino.")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DS.Colors.textSecondary)

                Text("Your local-first Mac companion for learning while you work.")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Screenshots are captured only when you use the hot key and are sent to the Ollama model running on this Mac.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Email + Start Button

    @ViewBuilder
    private var startButton: some View {
        if !companionManager.hasCompletedOnboarding && companionManager.allPermissionsGranted {
            Button(action: {
                companionManager.triggerOnboarding()
            }) {
                Text("Start")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DS.Colors.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: DS.CornerRadius.large, style: .continuous)
                            .fill(DS.Colors.accent)
                    )
            }
            .buttonStyle(.plain)
            .pointerCursor()
        }
    }

    // MARK: - Permissions

    private var settingsSection: some View {
        VStack(spacing: 2) {
            Text("PERMISSIONS")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            microphonePermissionRow

            speechRecognitionPermissionRow

            accessibilityPermissionRow

            screenRecordingPermissionRow

            if companionManager.hasScreenRecordingPermission {
                screenContentPermissionRow
            }

        }
    }

    private var accessibilityPermissionRow: some View {
        let isGranted = companionManager.hasAccessibilityPermission
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                Text("Accessibility")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Granted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Colors.success)
                }
            } else {
                HStack(spacing: 6) {
                    Button(action: {
                        // Triggers the system accessibility prompt (AXIsProcessTrustedWithOptions)
                        // on first attempt, then opens System Settings on subsequent attempts.
                        WindowPositionManager.requestAccessibilityPermission()
                    }) {
                        Text("Grant")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DS.Colors.textOnAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(DS.Colors.accent)
                            )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()

                    Button(action: {
                        // Reveals the app in Finder so the user can drag it into
                        // the Accessibility list if it doesn't appear automatically
                        // (common with unsigned dev builds).
                        WindowPositionManager.revealAppInFinder()
                        WindowPositionManager.openAccessibilitySettings()
                    }) {
                        Text("Find App")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DS.Colors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .stroke(DS.Colors.borderSubtle, lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                    .pointerCursor()
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var screenRecordingPermissionRow: some View {
        let isGranted = companionManager.hasScreenRecordingPermission
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.dashed.badge.record")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Screen Recording")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DS.Colors.textSecondary)

                    Text(isGranted
                         ? "Only takes a screenshot when you use the hotkey"
                         : "Quit and reopen after granting")
                        .font(.system(size: 10))
                        .foregroundColor(DS.Colors.textTertiary)
                }
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Granted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Colors.success)
                }
            } else {
                Button(action: {
                    // Triggers the native macOS screen recording prompt on first
                    // attempt (auto-adds app to the list), then opens System Settings
                    // on subsequent attempts.
                    WindowPositionManager.requestScreenRecordingPermission()
                }) {
                    Text("Grant")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Colors.textOnAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DS.Colors.accent)
                        )
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }

    private var screenContentPermissionRow: some View {
        let isGranted = companionManager.hasScreenContentPermission
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                Text("Screen Content")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Granted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Colors.success)
                }
            } else {
                Button(action: {
                    companionManager.requestScreenContentPermission()
                }) {
                    Text("Grant")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Colors.textOnAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DS.Colors.accent)
                        )
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }

    private var microphonePermissionRow: some View {
        let isGranted = companionManager.hasMicrophonePermission
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "mic")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                Text("Microphone")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Granted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Colors.success)
                }
            } else {
                Button(action: {
                    // Triggers the native macOS microphone permission dialog on
                    // first attempt. If already denied, opens System Settings.
                    let status = AVCaptureDevice.authorizationStatus(for: .audio)
                    if status == .notDetermined {
                        AVCaptureDevice.requestAccess(for: .audio) { _ in }
                    } else {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }) {
                    Text("Grant")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Colors.textOnAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DS.Colors.accent)
                        )
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }

    private var speechRecognitionPermissionRow: some View {
        let isGranted = companionManager.hasSpeechRecognitionPermission
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                Text("Speech Recognition")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Granted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Colors.success)
                }
            } else {
                Button(action: {
                    let status = SFSpeechRecognizer.authorizationStatus()
                    if status == .notDetermined {
                        SFSpeechRecognizer.requestAuthorization { _ in }
                    } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Grant")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Colors.textOnAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DS.Colors.accent)
                        )
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }

    private func permissionRow(
        label: String,
        iconName: String,
        isGranted: Bool,
        settingsURL: String
    ) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isGranted ? DS.Colors.textTertiary : DS.Colors.warning)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            if isGranted {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DS.Colors.success)
                        .frame(width: 6, height: 6)
                    Text("Granted")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DS.Colors.success)
                }
            } else {
                Button(action: {
                    if let url = URL(string: settingsURL) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Grant")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DS.Colors.textOnAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(DS.Colors.accent)
                        )
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }
        }
        .padding(.vertical, 6)
    }



    // MARK: - Show Clicky Cursor Toggle

    private var showClickyCursorToggleRow: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "cursorarrow")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
                    .frame(width: 16)

                Text("Show Clicky")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { companionManager.isClickyCursorEnabled },
                set: { companionManager.setClickyCursorEnabled($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .tint(DS.Colors.accent)
            .scaleEffect(0.8)
        }
        .padding(.vertical, 4)
    }

    private var speechToTextProviderRow: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "mic.badge.waveform")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.textTertiary)
                    .frame(width: 16)

                Text("Speech to Text")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DS.Colors.textSecondary)
            }

            Spacer()

            Text(companionManager.buddyDictationManager.transcriptionProviderDisplayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(DS.Colors.textTertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Local Brain

    private var localBrainRow: some View {
        HStack {
            Text("Brain")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DS.Colors.textSecondary)

            Spacer()

            Text("Local Qwen")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DS.Colors.success)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button(action: {
                NSApp.terminate(nil)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 11, weight: .medium))
                    Text("Quit Clicky")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .pointerCursor()

        }
    }

    // MARK: - Visual Helpers

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(DS.Colors.background)
            .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private var statusDotColor: Color {
        if !companionManager.isOverlayVisible {
            return DS.Colors.textTertiary
        }
        switch companionManager.voiceState {
        case .idle:
            return DS.Colors.success
        case .listening:
            return DS.Colors.blue400
        case .processing, .responding:
            return DS.Colors.blue400
        }
    }

    private var statusSymbol: String {
        switch companionManager.voiceState {
        case .idle: return companionManager.isOverlayVisible ? "sparkles" : "circle"
        case .listening: return "waveform"
        case .processing: return "ellipsis"
        case .responding: return "speaker.wave.2"
        }
    }

    private var statusDetail: String {
        if !companionManager.allPermissionsGranted { return "A few permissions are still needed" }
        if companionManager.isResponseInFlight { return "Working with your local model" }
        let shortcut = BuddyPushToTalkShortcut.ShortcutOption(rawValue: pushToTalkShortcut)?.displayText ?? "ctrl + option"
        return "Hold \(shortcut) to talk"
    }

    private var statusText: String {
        if !companionManager.hasCompletedOnboarding || !companionManager.allPermissionsGranted {
            return "Setup"
        }
        if !companionManager.isOverlayVisible {
            return "Ready"
        }
        switch companionManager.voiceState {
        case .idle:
            return "Active"
        case .listening:
            return "Listening"
        case .processing:
            return "Processing"
        case .responding:
            return "Responding"
        }
    }

}
