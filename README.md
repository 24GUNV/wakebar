# Wakebar

Wakebar is a native macOS menu-bar app for starting AI coding sessions before a scheduled wake time.

Set one wake time. Wakebar prepares Claude Code and Codex a few minutes earlier, then coordinates an optional alarm on an iPhone. A minimal provider prompt uses `hi` in a fresh temporary session.

## Current status

This repository contains native macOS and iPhone applications with shared scheduling logic.

- SwiftUI provides the menu-bar summary and schedule editor.

- Schedules persist as version-tolerant JSON in Application Support.

- The schedule compiler produces the initial prompt, phone alarm, and five-hour refresh events.

- An execution ledger prevents the same compiled event from running twice.

- Provider-specific preview adapters model Claude Routine and Codex scheduling capabilities.

- Provider actions remain in preview mode and do not send live prompts by default.

- The iPhone companion receives schedules through the user’s private CloudKit database and registers them with AlarmKit.

- The iPhone confirms accepted or disabled revisions back to the Mac through a separate CloudKit acknowledgement.

- AlarmKit and cross-device delivery still require an iOS 26 physical-device test before release.

## Intended execution paths

- **Claude Code:** Use a Claude Routine so the Mac can be off.
- **Codex:** Use a hosted ChatGPT scheduled task so the Mac can be off.
- **Alarm:** Use an iPhone companion app with AlarmKit.

The app must verify each step independently. A scheduled event is not the same as a sent prompt, and a sent prompt is not proof that a usage window reset.

See [provider and alarm integrations](Docs/INTEGRATIONS.md) for the current capability boundaries.

## Project structure

- `Sources/WakebarCore`: schedule, provider, persistence, and execution logic.
- `Sources/WakebarApp`: menu-bar application and SwiftUI views.
- `Sources/WakebarPhone`: iPhone companion, AlarmKit status, and CloudKit delivery interface.
- `Tests/WakebarTests`: deterministic schedule tests.
- `project.yml`: macOS and iOS Xcode target definitions.
- `Scripts`: local packaging and launch scripts.

## Build

Requirements:

- macOS 14 or later
- Xcode 26 or later
- An Apple development team with the Wakebar CloudKit container enabled

Run the tests:

```sh
swift test
```

Create a signed macOS archive:

```sh
WAKEBAR_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./Scripts/package_app.sh release
```

Build and launch the debug app:

```sh
WAKEBAR_DEVELOPMENT_TEAM=YOUR_TEAM_ID ./Scripts/compile_and_run.sh
```

GitHub Actions builds the macOS and iPhone Debug and Release configurations with Xcode 26.6. It also runs 67 XCTest tests on macOS. The local Command Line Tools installation can build `WakebarCore`, but it does not include the iOS 26 SDK.

Before distributing the apps, complete the signed physical-device checks in the [release checklist](Docs/RELEASE_CHECKLIST.md).

## Safety boundaries

- Store provider secrets in Keychain.
- Never run provider commands through a shell string.
- Record occurrence identifiers before live execution to prevent duplicate prompts.
- Keep new provider connections in preview mode until the user confirms them.
- Do not upload consumer subscription credentials to a hosted Wakebar service.

## Reference project

The interface takes structural inspiration from the MIT-licensed [CodexBar](https://github.com/steipete/CodexBar). See [REFERENCES.md](REFERENCES.md).
