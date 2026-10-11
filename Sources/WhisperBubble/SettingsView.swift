import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var preferences: Preferences
    @State private var keyDraft = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "waveform").font(.system(size: 27, weight: .medium)).foregroundStyle(Color.accentColor)
                    .frame(width: 54, height: 54).background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Whisper Bubble").font(.system(size: 23, weight: .semibold))
                    Text("Your voice, wherever you write.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(24)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    group("OpenAI", icon: "key") {
                        HStack {
                            SecureField(controller.keySaved ? "Enter a replacement API key" : "Enter your OpenAI API key", text: $keyDraft)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("OpenAI API key")
                                .onSubmit(saveKey)
                            Button("Save", action: saveKey).disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: controller.keySaved ? "checkmark.shield.fill" : "circle.dashed")
                                .foregroundStyle(controller.keySaved ? Color.green : Color.secondary)
                            Text(controller.keySaved ? "Key saved in macOS Keychain" : "No API key saved").font(.system(size: 11))
                            Spacer()
                            if controller.keySaved { Button("Remove", action: controller.removeKey).buttonStyle(.link).font(.system(size: 11)) }
                        }
                        if !controller.keychainNotice.isEmpty {
                            Text(controller.keychainNotice).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Text("Audio is sent to OpenAI when you finish dictating. API usage is billed to your OpenAI API account; a ChatGPT subscription does not supply an API key.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Link("Manage API keys ↗", destination: URL(string: "https://platform.openai.com/api-keys")!).font(.system(size: 11))
                            Spacer()
                            Picker("Model", selection: $preferences.model) {
                                Text("GPT-4o Mini Transcribe").tag("gpt-4o-mini-transcribe")
                                Text("GPT-4o Transcribe").tag("gpt-4o-transcribe")
                                Text("Whisper 1").tag("whisper-1")
                            }.frame(width: 285)
                        }
                        Picker("Language", selection: $preferences.language) {
                            Text("Auto detect").tag("")
                            Text("English").tag("en")
                            Text("German").tag("de")
                            Text("French").tag("fr")
                            Text("Spanish").tag("es")
                            Text("Italian").tag("it")
                            Text("Portuguese").tag("pt")
                            Text("Dutch").tag("nl")
                            Text("Hindi").tag("hi")
                            Text("Tamil").tag("ta")
                            Text("Japanese").tag("ja")
                            Text("Chinese").tag("zh")
                        }.frame(width: 285, alignment: .leading)
                    }
                    group("Controls & appearance", icon: "keyboard") {
                        Toggle("Hold Fn / Globe to dictate", isOn: $preferences.fnEnabled)
                        HStack {
                            Text("Fallback hold shortcut")
                            Spacer()
                            Picker("Fallback hold shortcut", selection: $preferences.fallback) {
                                ForEach(FallbackShortcut.allCases) { Text($0.title).tag($0) }
                            }.labelsHidden().frame(width: 205)
                        }
                        Text("Hold to speak; release to transcribe. If Fn also triggers emoji or macOS dictation, set “Press Fn / Globe key to” to “Do Nothing” in macOS Keyboard settings. Choose a fallback shortcut unused by your apps.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Picker("Bubble position", selection: $preferences.location) {
                            ForEach(BubbleLocation.allCases) { Text($0.title).tag($0) }
                        }
                        Toggle("Show floating bubble", isOn: $preferences.bubbleVisible)
                        HStack {
                            Text("Bubble background")
                            Spacer()
                            Text("Clearer").font(.system(size: 10)).foregroundStyle(.secondary)
                            Slider(value: $preferences.bubbleOpacity, in: 0.08...0.6)
                                .frame(width: 140).accessibilityLabel("Bubble background opacity")
                            Text("Frosted").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Toggle("Insert into the original text field", isOn: $preferences.automaticInsertion)
                        Toggle("Use clipboard paste for terminals and compatible editors", isOn: $preferences.pasteFallback)
                            .disabled(!preferences.automaticInsertion)
                        Text("Insertion stops if focus, text, or the selection changes. Password fields are excluded. Paste restores the previous clipboard after one second. Terminal dictation stays on one line and does not press Return. The latest transcript is always available from the menu.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    group("Mac permissions", icon: "hand.raised") {
                        permission("Microphone", detail: "Record your voice", granted: controller.microphoneGranted, action: controller.requestMicrophone)
                        permission("Accessibility", detail: "Insert text into the focused field", granted: controller.accessibilityGranted, action: controller.requestAccessibility)
                        permission("Input Monitoring", detail: "Detect Fn and the fallback shortcut globally", granted: controller.keyboardGranted && controller.shortcutRunning, action: controller.requestKeyboard)
                        Text("Enable Whisper Bubble in Privacy & Security. If macOS asks, quit and reopen the app after granting access. Click dictation and copying work without keyboard or Accessibility access.")
                            .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button("Refresh permissions", action: controller.refreshPermissions).buttonStyle(.link).font(.system(size: 11))
                    }
                }.padding(24)
            }
            Divider()
            HStack {
                Text("Personal edition · 1.0.4").font(.system(size: 10)).foregroundStyle(.tertiary)
                Spacer()
                Text("Click to start / stop · Esc to cancel · 2 min limit").font(.system(size: 10)).foregroundStyle(.secondary)
            }.padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(width: 570, height: 660)
    }

    private func saveKey() { if controller.saveKey(keyDraft) { keyDraft = "" } }

    private func group<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            content()
        }.font(.system(size: 12))
    }

    private func permission(_ title: String, detail: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle").foregroundStyle(granted ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button(granted ? "Manage" : "Enable", action: action).controlSize(.small)
        }
    }
}

struct TranscriptView: View {
    @ObservedObject var controller: AppController
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Latest transcript", systemImage: "text.alignleft").font(.headline)
                Spacer()
                Button("Clear", action: controller.clearTranscript).buttonStyle(.link)
            }
            if !controller.transcriptNotice.isEmpty {
                Text(controller.transcriptNotice).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if controller.transcriptNeedsInsertionHelp {
                    Button("Insertion Settings…", action: controller.showSettings).buttonStyle(.link)
                }
            }
            ScrollView {
                Text(controller.lastTranscript).font(.system(size: 15)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
            }.background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Text("Kept in memory until cleared or you quit.").font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(copied ? "Copied ✓" : "Copy Transcript") {
                    controller.copyTranscript()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                }.keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }.padding(22).frame(minWidth: 380, minHeight: 220)
    }
}
