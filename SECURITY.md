# Security Policy

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately via GitHub's **[Report a vulnerability](https://github.com/dvarner/Talk2Text/security/advisories/new)**
button (Security tab → Advisories). If that isn't available, open a minimal
issue asking a maintainer to make contact — without details — and we'll move to
a private channel.

When reporting, please include:
- affected app (desktop / mobile) and version or commit,
- a description and impact,
- steps to reproduce or a proof of concept.

We aim to acknowledge reports within a few days and to keep you updated as we
investigate and fix.

## Supported versions

This is an early-stage project; only the latest release and the default branch
receive security fixes.

## Scope & data handling

Talk2Text is designed to run locally. Useful context for assessing reports:

- **On-device transcription (default)** runs fully offline — audio and
  transcripts never leave the device.
- **Cloud transcription (optional)** uploads your **audio** to the
  OpenAI-compatible endpoint you configure.
- **Translation (optional)** sends your **transcript text** (never the audio)
  to the Anthropic API.
- API keys are stored in the OS secure store (Keychain / Keystore) and are
  never written to settings, logs, or transcript files.

## Out of scope

- Issues requiring a rooted/jailbroken device or physical access.
- Vulnerabilities in third-party dependencies (report those upstream; we'll
  bump versions once fixed).
