# Validation

Current version: **1.0.4**, 11 October 2026.

## Automated checks

- **36 core cases, 140 assertions, zero failures.**
- **8 native Accessibility-value checks, zero failures.**
- **9 native clipboard checks, zero failures.** The user's clipboard was untouched.
- Universal arm64/x86_64 release compilation, strict signature verification, plist validation, compressed DMG verification, and SHA-256 verification passed.

The core runner covers recording lifecycle, stale/cancelled callbacks, overlapping inputs, Fn and fallback shortcuts, silent/short audio, secure fields, focus departure and return, changed text/app/cursor rejection, native-marker selection rules, Unicode ranges, terminal paste routing, control-character handling, multipart requests, mocked API responses, and pending request cancellation.

Native Accessibility fixtures construct real `AXValue` and `AXTextMarkerRange` objects without inspecting another application. Clipboard fixtures use a uniquely named private pasteboard to check restoration, empty clipboard handling, and preservation of later copies. The user's general clipboard is untouched.

Build verification checks both arm64 and x86_64, the bundle plist, strict code signing, the compressed disk image, and its SHA-256 checksum.

## Observed behavior and limits

- The user reported successful transcription after adding API credits, insertion in Chrome's address bar, and subsequently working insertion in ChatGPT.
- The user reported gray suggestion-like text and a stationary cursor in a terminal. Version 1.0.4 routes terminal input through paste, avoids Accessibility display-value replacement, and advances ordinary character-range carets after direct selected-text insertion. The user's particular terminal has not been identified or retested yet.
- The actual 72 × 26 point control was rendered offscreen in all phases. Default background samples had alpha approximately 0.294–0.298; the outer canvas was transparent. Native desktop blur was not assessed by that capture.
- The initial native app launch and Settings layout were inspected. Microphone, Accessibility, Input Monitoring, and automatic insertion were enabled in the prior running copy. No key or transcript content was read.
- The consolidated 1.0.4 app was launched from the existing canonical path. The user approved its existing Keychain access and confirmed the bubble was visible; native inspection then confirmed its idle control.
- Warp, ChatGPT, and macOS SecurityAgent UI inspection is blocked by the computer-use tool. Those applications were not inspected through another method. The attempted live Warp check could not proceed and remains manual.

## Manual checks

These require the user's hardware, permissions, API account, or chosen target app:

1. Microphone quality, physical Fn/Globe delivery, and speech waveform response.
2. A live paid OpenAI transcription with the user's model/account access.
3. Insertion in the user's actual terminal: text enters the editable command buffer, the caret advances, and no command is submitted.
4. Cross-app focus changes during transcription, custom editors with limited Accessibility support, and secure fields.
5. Intel execution and the minimum supported macOS 13 system. Both architectures compile; local execution is on Apple silicon.

The app is ad-hoc signed and not notarized. Replacing its binary may require macOS to approve the updated app's Accessibility and existing Keychain access again.
