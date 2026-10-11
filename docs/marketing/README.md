# Speaklet marketing kit

Speaklet is a native Mac dictation app by Dhayanand Baskar. These assets and copy are available under the repository’s Apache 2.0 license. The app control images come from the production SwiftUI view; the animation uses sample microphone levels.

## Tagline

**Hold a key. Say it. Keep going.**

## One line

Speaklet is a tiny Mac dictation app that turns your voice into text at the cursor where supported.

## Short description

Hold Fn/Globe, say what’s on your mind, and release. Speaklet transcribes your words into the field you’re writing in where supported. Its tiny dark capsule expands into a live waveform as you speak. Free and open source under Apache 2.0, for macOS 13+. Bring your own OpenAI API key; API usage is billed separately.

## Longer description

Speaklet puts dictation close to your keyboard. Hold Fn/Globe or a configurable shortcut, speak, and release to transcribe. Prefer a mouse? Click the small floating capsule to start and stop. The native Mac control stays compact at rest and expands to show microphone activity while recording.

Speaklet attempts insertion in the original text field, with safeguards for focus and cursor changes. Terminals and compatible editors use guarded clipboard paste; terminal dictation does not press Return. When a field cannot accept insertion, your transcript remains available to copy.

The app is free and open source under Apache 2.0. It requires macOS 13 or later and your own OpenAI API key. API usage is billed separately from ChatGPT subscriptions. Audio is sent to OpenAI after recording; local temporary recordings are deleted after completion or cancellation.

## Launch post — ready to paste

I built Speaklet, a small dictation app for the Mac.

Hold Fn, speak, release. Your words go into the field you’re writing in where supported. A tiny dark capsule expands while you talk, then gets out of the way.

It’s native Swift, free, and now open source under Apache 2.0. There’s also guarded paste for terminals and a copy fallback for fields that cannot accept insertion.

You’ll need macOS 13+ and your own OpenAI API key; API usage is billed separately.

Download and setup guide: https://dhayanandbaskar.github.io/apps/speaklet/
Source: https://github.com/DhayanandBaskar/speaklet

## Short social post

Meet Speaklet: hold a key, speak, and keep going. A tiny native Mac dictation app, free and open source under Apache 2.0. macOS 13+, Apple silicon + Intel. Bring your own OpenAI API key; usage is billed separately.

https://dhayanandbaskar.github.io/apps/speaklet/

## Feature bullets

- Hold Fn/Globe or an alternative shortcut; click to start and stop.
- A 42 × 18-point dark capsule expands to 88 × 28 while recording.
- A waveform follows actual microphone input.
- Insert in the original field where supported, or copy the transcript.
- Guarded clipboard paste for terminals and compatible editors.
- Terminal dictation stays on one line and never presses Return.
- Native Swift, macOS 13+, Apple silicon and Intel.
- Open source under Apache 2.0.

## Product facts for posts

- The app is free. OpenAI API usage is separately billed.
- Speaklet currently uses an API key, not a ChatGPT subscription login.
- The key is stored in macOS Keychain. Audio goes to OpenAI for transcription.
- The personal build is locally signed, not Apple-notarized.
- Some fields require the copy fallback. Automatic insertion is not universal.
- No made-up accuracy, speed, customer-count, or offline claims.

[Download the complete marketing kit](https://github.com/DhayanandBaskar/speaklet/releases/latest/download/Speaklet-Marketing-Kit.zip).

## Files

- [Landscape share image](speaklet-social.png) — 1200 × 630, used by the product page’s link preview.
- [Square share image](speaklet-square.png) — 1080 × 1080, for social posts.
- [Editable landscape graphic](speaklet-social.svg).
- [Editable square graphic](speaklet-square.svg).
- [App icon](speaklet-icon.png) — 256 × 256.
- [Actual control animation](../bubble-preview.gif) — sample microphone levels.

## Links

- Product and setup: https://dhayanandbaskar.github.io/apps/speaklet/
- Apps directory: https://dhayanandbaskar.github.io/apps/
- Download: https://github.com/DhayanandBaskar/speaklet/releases/latest/download/Speaklet.dmg
- Source: https://github.com/DhayanandBaskar/speaklet
- Release notes and checksum: https://github.com/DhayanandBaskar/speaklet/releases/latest

## Screenshot-based artwork

[Product illustration](screenshot-kit/speaklet-illustration.png) — 1536 × 1024, generated from the actual Settings and capsule captures using built-in image generation. [Exact prompt and references](screenshot-prompts.json). The UI is simplified and restyled; this is an illustration, not a raw screenshot.

[Actual Settings screenshot](screenshot-kit/speaklet-settings.jpg) and [controls screenshot](screenshot-kit/speaklet-controls.jpg) — unchanged native captures from the installed 1.0.6 build, with the API key field empty. Captures can include the pointer and macOS sharing indicator. [Capsule reference](screenshot-kit/speaklet-capsule.jpg) includes the captured pointer and is supplied as generation provenance.

[Download screenshots, illustrations, prompts, and post copy for Speaklet + Still](https://dhayanandbaskar.github.io/apps/assets/Mac-App-Media-Kit.zip). The media license does not publish or license Still’s app source.
