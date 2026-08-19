# Wakebar

Wakebar is a native macOS menu-bar app for starting AI coding sessions before a scheduled wake time.

Set one wake time. Wakebar prepares Claude Code and Codex a few minutes earlier, then coordinates an optional alarm on an iPhone. A minimal provider prompt uses `hi` in a fresh temporary session.

## Current status

This repository contains the first native application draft.

- SwiftUI provides the menu-bar summary and schedule editor.
- Schedules persist as version-tolerant JSON in Application Support.
- The schedule supports weekdays, lead time, time zones, skip-next, and five-hour repeats.
- Provider actions use preview adapters and do not send live prompts.
- The iPhone alarm remains an interface placeholder until the companion app adds AlarmKit.

## Intended execution paths

- **Claude Code:** Use a Claude Routine so the Mac can be off.
- **Codex:** Use a verified web scheduled task or an opt-in always-on runner.
- **Alarm:** Use an iPhone companion app with AlarmKit.

The app must verify each step independently. A scheduled event is not the same as a sent prompt, and a sent prompt is not proof that a usage window reset.

## Project structure

- `Sources/WakebarCore`: schedule, provider, persistence, and execution logic.
- `Sources/WakebarApp`: menu-bar application and SwiftUI views.
- `Tests/WakebarTests`: deterministic schedule tests.
- `Scripts`: local packaging and launch scripts.

## Build

Requirements:

- macOS 14 or later
- Swift 6.2 or later
- A Swift compiler that matches the installed macOS software development kit

Run the tests:

```sh
swift test
```

Build an ad-hoc signed app bundle:

```sh
./Scripts/package_app.sh release
```

Build and launch the debug app:

```sh
./Scripts/compile_and_run.sh
```

The current machine has a compiler and software development kit version mismatch. Source parsing succeeds, but a semantic build cannot complete until Xcode selects a matching toolchain.

## Safety boundaries

- Store provider secrets in Keychain.
- Never run provider commands through a shell string.
- Record occurrence identifiers before live execution to prevent duplicate prompts.
- Keep new provider connections in preview mode until the user confirms them.
- Do not upload consumer subscription credentials to a hosted Wakebar service.

## Reference project

The interface takes structural inspiration from the MIT-licensed [CodexBar](https://github.com/steipete/CodexBar). See [REFERENCES.md](REFERENCES.md).
