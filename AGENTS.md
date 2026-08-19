# Repository guidelines

## Scope

Wakebar is a native macOS menu-bar app. It schedules minimal prompts for Claude Code and Codex, and it coordinates an optional iPhone alarm.

## Structure

- `Sources/WakebarCore`: schedule, provider, persistence, and execution logic.
- `Sources/WakebarApp`: SwiftUI application and views.
- `Tests/WakebarTests`: deterministic tests for core logic.
- `Scripts`: local build and app-bundle scripts.

## Development rules

- Target macOS 14 or later and Swift 6.2 or later.
- Use Swift concurrency.
- Do not use Grand Central Dispatch.
- Keep each Swift type in its own file.
- Use `@MainActor @Observable` for shared view state.
- Keep credentials out of the repository and store secrets in Keychain.
- Keep all new schedules in preview mode until the user confirms a live provider connection.
- Never report that a prompt was sent until the provider returns a successful receipt.
- Never report that a usage window started until the provider confirms the reset state.

## Verification

Run these checks before a handoff:

```sh
find Sources Tests -name '*.swift' -print0 | xargs -0 -n 1 swiftc -frontend -parse
swift test
```

The second command requires a Swift compiler that matches the installed macOS software development kit.
