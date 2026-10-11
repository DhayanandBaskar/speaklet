# Whisper Bubble

A native macOS dictation app with a small translucent floating control. Hold Fn/Globe, speak, and release to transcribe into the focused text field. You can also click the bubble to start and stop. The waveform follows the microphone's actual audio level.

The pill stays **72 × 26 points** while idle, recording, transcribing, or showing an error. Settings controls its position and transparency; hover or right-click for status.

Requires macOS 13 or later and an OpenAI API key with API billing enabled. ChatGPT subscriptions do not include API usage. This personal build is ad-hoc signed and is not notarized.

## Build

Apple's Command Line Tools provide the required Swift toolchain and macOS SDK. There are no third-party dependencies.

```sh
git clone git@github.com:DhayanandBaskar/whisper-bubble.git
cd whisper-bubble
bash scripts/test.sh
bash scripts/build.sh
```

Quit Whisper Bubble before building an update. The script compiles Apple silicon and Intel binaries, signs and verifies the universal app, and creates a compressed installer. Every build replaces the same three outputs:

- `build/dist/Whisper Bubble.app`
- `build/dist/Whisper-Bubble.dmg`
- `build/dist/SHA256SUMS.txt`

Temporary packaging copies are removed automatically. Generated files are excluded from Git.

If your Mac has separate work and personal SSH profiles, clone this repository with the personal alias instead:

```sh
git clone git@github.com-personal:DhayanandBaskar/whisper-bubble.git
```

## Install and use

The current installer and checksum are available in the [latest GitHub release](https://github.com/DhayanandBaskar/whisper-bubble/releases/latest). Sign in with the personal account that owns this private repository.

1. Open `build/dist/Whisper-Bubble.dmg`, drag **Whisper Bubble.app** into **Applications**, and launch that copy. Quit and replace the existing app when updating. Keep one installed copy.
2. If macOS blocks this personal build, use **System Settings → Privacy & Security → Open Anyway**. An ad-hoc signed update may require renewed Accessibility and Keychain approval. Saved preferences and the API key are retained.
3. Open **Settings** from the bubble's right-click menu or the waveform menu-bar icon. Save your OpenAI API key; it is stored in macOS Keychain.
4. Enable **Microphone**, **Accessibility**, and **Input Monitoring** using the app's permission guidance. Enable the installed copy, then quit and reopen if macOS requests it.
5. Focus the text field where you want to write. Hold Fn/Globe and release after speaking, or use **Control + Option + Space**. Settings offers alternate shortcuts. If macOS reserves Fn for another action, set its Keyboard preference to **Do Nothing** or use the fallback shortcut.

The bubble preserves the other app's focus. Escape cancels recording or a pending request; recordings stop after two minutes. **Latest Transcript** and **Copy Latest Transcript** remain available until cleared or the app quits.

To check insertion without recording or API usage, focus a disposable text field and choose **Test Text Insertion** from the bubble's right-click menu. This inserts `Whisper Bubble test.` and replaces any selected text.

## Text insertion

Insertion captures the original field, app, text when exposed, and cursor or native text-marker selection. Moving to another field, editing text, or moving the cursor while dictating cancels automatic insertion. Secure/password fields are excluded. Unsupported fields produce a copyable transcript with an explanation.

Ordinary single-line fields use direct Accessibility insertion where supported. Terminal.app, iTerm2, Warp, and identified integrated terminal fields use guarded Command-V instead of writing their Accessibility display values. Multiline editors also prefer paste when enabled. Turn on **Use clipboard paste for terminals and compatible editors** in Settings.

Terminal dictation replaces newlines and control characters with spaces and sends no Return key. It does not submit the command. Other editors retain multiline text. This matters because a pasted Return can execute a terminal command; see [Apple's Terminal guide](https://support.apple.com/guide/terminal/trml1019/mac).

Paste rechecks the captured field and restores the previous clipboard after one second, unless you copied something else in the meantime. **Paste sent** means the shortcut was delivered; an application may still reject it. Rich text fields can expose native cursor markers instead of plain string offsets. Electron's documented [Accessibility support](https://www.electronjs.org/docs/latest/tutorial/accessibility) is enabled per process where available.

## Privacy

- The API key is kept in Keychain, never in source or preferences.
- Completed recordings are sent over HTTPS to OpenAI's transcription endpoint. The default model is `gpt-4o-mini-transcribe`; Settings also offers `gpt-4o-transcribe` and `whisper-1`.
- Redirects are refused, network sessions are ephemeral, and keys, audio, API responses, and transcripts are not logged.
- Private temporary recordings are deleted after completion or cancellation. Forced termination can leave a private temporary folder for macOS to clean up. Transcripts are kept only in memory.
- Cancellation stops pending local work. It cannot recall an upload already sent to OpenAI.
- No login item is installed and macOS Keyboard preferences are not changed.

## Validation

`scripts/test.sh` checks lifecycle and shortcuts, focus and cursor safeguards, terminal routing, Unicode, transcription request/response handling, and cancellation using fixtures. Native checks decode actual Accessibility value objects and test clipboard restoration using a private named pasteboard. They do not read another app, touch the user's clipboard, use the microphone, or contact OpenAI.

Source is organized into pure rules in `Sources/WhisperCore`, reusable macOS adapters in `Sources/WhisperMacSupport`, and app integration in `Sources/WhisperBubble`. See [VALIDATION.md](VALIDATION.md) for results and manual checks.
