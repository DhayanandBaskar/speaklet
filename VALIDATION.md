# Validation

Current version: **Speaklet 1.0.6**, 11 October 2026.

## Automated checks

The behavior-suite counts below are from version 1.0.5. Version 1.0.6 changes branding and packaging; both universal release compilation and the installer checks were run for the renamed app.

- **38 core cases, 151 assertions, zero failures.**
- **8 native Accessibility-value checks, zero failures.**
- **9 native clipboard checks, zero failures.** The user's clipboard was untouched.
- **3 signing identity checks, zero failures.** Different binaries retained the same certificate-bound designated requirement, satisfied each other's requirement, and rejected a same-identifier ad-hoc executable.
- Universal arm64/x86_64 release compilation, strict signature verification, plist validation, compressed DMG verification, and SHA-256 verification passed.

The credential cache checks verify one read across repeated uses, a fresh read after clearing, retry after denial, replacement, and removal without stale credentials. No real credential was read.

The core runner covers recording lifecycle, stale/cancelled callbacks, overlapping inputs, Fn and fallback shortcuts, silent/short audio, secure fields, focus departure and return, changed text/app/cursor rejection, native-marker selection rules, Unicode ranges, terminal paste routing, control-character handling, multipart requests, mocked API responses, and pending request cancellation.

Native Accessibility fixtures construct real `AXValue` and `AXTextMarkerRange` objects without inspecting another application. Clipboard fixtures use a uniquely named private pasteboard to check restoration, empty clipboard handling, and preservation of later copies. The user's general clipboard is untouched.

Build verification checks both arm64 and x86_64, the bundle plist, strict code signing, the compressed disk image, and its SHA-256 checksum.

## Observed behavior and limits

- The user reported successful transcription after adding API credits, insertion in Chrome's address bar, and subsequently working insertion in ChatGPT.
- The user reported gray suggestion-like text and a stationary cursor in a terminal. Version 1.0.4 routes terminal input through paste, avoids Accessibility display-value replacement, and advances ordinary character-range carets after direct selected-text insertion. The user identified Warp or an integrated terminal; live Warp verification is blocked by the computer-use tool and remains manual.
- The production control was rendered in idle, recording, processing, and error states in both light and dark themes. Idle is 42 × 18 points; recording is 88 × 28. A 108-frame sequence captured real SwiftUI transitions with fixture meter values, including 17 distinct capsule widths from 42 to 88 points. Sample background pixels were RGBA (9, 9, 9, 194) idle and (1, 1, 1, 247) recording; the outer canvas is transparent. Native desktop blur remains a separate live check.
- The redesigned 1.0.5 control was launched and visually inspected. Startup and Settings opened without a secret-key prompt; Settings correctly reported the existing key using metadata alone. The app reported the old build’s privacy approvals as unavailable, matching the ad-hoc identity issue.
- The final certificate-signed 1.0.5 app was installed and launched from `/Applications/Whisper Bubble.app`. Its signature and universal architectures were verified. Startup and Settings again opened without reading the saved secret. Microphone access was retained; initially, the installed app reported Accessibility and Input Monitoring unavailable while System Settings still showed old enabled entries. Both stale Whisper Bubble entries were removed and the Applications copy added using System Settings. The user completed macOS authentication; the app was quit and reopened. The running app then showed all three permissions granted, and its keyboard-listener failure notice was absent. The one-time migration is complete on this Mac.
- The installed Settings view has no redundant Refresh permissions button. Permission checks run automatically every two seconds; a failed keyboard listener is no longer displayed as denied Input Monitoring.
- Speaklet 1.0.6 was built for both architectures, and its app and DMG were verified. The renamed app's designated requirement exactly matches the installed Whisper Bubble 1.0.5 requirement and passes verification against it. The app is installed at `/Applications/Speaklet.app`; the previous installed copy was moved recoverably to Trash. On launch, Speaklet's Settings showed Microphone, Accessibility, and Input Monitoring granted, with the keyboard listener available, the saved-key metadata recognized, and the existing language, shortcut, position, and appearance settings retained. No new permission or saved-key prompt appeared during launch or Settings inspection.
- The initial native app launch and Settings layout were inspected. Microphone, Accessibility, Input Monitoring, and automatic insertion were enabled in the prior running copy. No key or transcript content was read.
- The consolidated 1.0.4 app was launched from the existing canonical path. The user approved its existing Keychain access and confirmed the bubble was visible; native inspection then confirmed its idle control.
- Warp, ChatGPT, and macOS SecurityAgent UI inspection is blocked by the computer-use tool. Those applications were not inspected through another method. The attempted live Warp check could not proceed and remains manual.

## Public release 1.0.7

- Core fixtures: 38 cases, 151 assertions; native Accessibility fixtures: 8; private clipboard fixtures: 9. All passed.
- Persistent-signing checks: 3 passed. The new release’s designated requirement exactly matches the installed Speaklet 1.0.6 requirement.
- Both architectures compiled, strict signing and plist checks passed, and the DMG and SHA-256 checksum verified.
- LICENSE and NOTICE were compared byte-for-byte with the source at both the disk-image root and inside the mounted app bundle.
- This release adds Apache 2.0 licensing and a marketing kit. The build script permits an installed Applications copy to keep running, while protecting a generated copy in build/dist from replacement.
- The installed app remains 1.0.6 on this Mac; 1.0.7 was packaged for the public release. No privacy settings or saved credentials were changed.

## Manual checks

These require the user's hardware, permissions, API account, or chosen target app:

1. Microphone quality, physical Fn/Globe delivery, and speech waveform response.
2. A live paid OpenAI transcription with the user's model/account access.
3. Insertion in the user's actual terminal: text enters the editable command buffer, the caret advances, and no command is submitted.
4. Cross-app focus changes during transcription, custom editors with limited Accessibility support, and secure fields.
5. Intel execution and the minimum supported macOS 13 system. Both architectures compile; local execution is on Apple silicon.

The app is signed with a persistent local certificate and is not notarized. The one-time transition from the old ad-hoc identity requires macOS consent for the new identity; this was completed and verified on this Mac. Future builds reuse the same certificate; the private key is kept in the login Keychain, outside the repository.
