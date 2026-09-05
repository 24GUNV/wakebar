# Wakebar

A native macOS menu-bar app that schedules small prompts for Claude Code and Codex and keeps their usage limits in view.

I built Wakebar because I wanted my coding subscription's usage window to start before I sat down to work. Choose a time and Wakebar asks the selected provider for a one-word reply, then checks whether its usage data changed.

Suppose a five-hour window begins with your first request. Starting at 07:00 instead of 09:00 moves the reset from 14:00 to 12:00. The provider controls the actual limits and reset behavior; Wakebar displays what it reports.

**Status:** Experimental personal project under active development. Build from source for now; no packaged release is available yet.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="Docs/Images/wakebar-menu-dark.png">
  <img alt="Wakebar menu showing a morning schedule, provider status, and usage bars for Claude Code and Codex" src="Docs/Images/wakebar-menu-light.png" width="372">
</picture>

## What it does

- Schedule a prompt before your chosen wake time, on selected weekdays.
- Use **Every reset** to schedule another prompt after the provider-reported window resets.
- View usage and reset times from the menu bar, or send a prompt with **Start now**.
- Confirm a started window from provider usage data, rather than assuming an accepted request started one.

Each wake consumes subscription usage. Requests ask only for `hi`, with no tool use. Wakebar reuses your existing subscription login; it does not require a separately billed API key.

## How it works

![How Wakebar works](Docs/Images/wakebar-flow.svg)

| Provider | Where the prompt runs | What needs to stay running |
| --- | --- | --- |
| Claude Code | A cloud Routine that Wakebar creates and updates | An already-synced Routine can fire while your Mac is asleep. Wakebar must run to update future schedules. |
| Codex | A small request sent from your Mac using the Codex CLI login | Wakebar must be running. After sleep, it checks whether a missed prompt is still needed. |

Select **Connect Claude Code** or **Connect Codex** to allow access to that provider’s existing login. Claude also uses macOS’s app-specific Keychain authorization. Saving a schedule alone does not grant credential access.

Wakebar manages only Claude Routines with the `Wakebar ·` name prefix. It compares the saved plan with existing Routines, updates changed ones, and removes obsolete ones. Retrying a partially completed sync reuses Routines already created.

**Every reset** follows the limit each provider reports. A weekly-only Codex limit schedules a wake after the weekly reset, rather than creating a five-hour schedule. Claude's next reset Routine fires in the cloud, but keeping the chain updated requires Wakebar's background usage checks.

If usage cannot be read, Wakebar waits instead of sending an automatic Codex prompt or deleting Claude’s last reset Routine.

These integrations depend on provider endpoints that can change. The Claude Routines API is undocumented, and the Codex integration uses its backend endpoint directly. This is an independent project, unaffiliated with Anthropic or OpenAI.

## Build and run

### Ask your coding agent

If you use a coding agent with access to your Mac, paste this prompt into it:

```text
Help me build and run Wakebar from https://github.com/24GUNV/wakebar.

Clone the repository into a suitable local folder, or use my existing checkout
without overwriting changes. Read README.md and AGENTS.md first.

Check for macOS 14+, full Xcode with Swift 6.2+, and XcodeGen. Install XcodeGen
with Homebrew if available. If Xcode or Homebrew is missing, explain what I
need to install before continuing.

Generate the Xcode project and run the documented non-live checks. Use the
repository's local signing and build scripts to build and launch the app.
If a signing identity is needed, guide me through setup_dev_signing.sh in my
own terminal; I will enter any macOS password there, not in this chat.

Let me complete provider sign-in and choose my schedule in the app.
Do not read or print provider tokens, enable a live schedule, use Start now,
or run live provider tests as part of installation.

Tell me where the app was built and whether it launched successfully.
```

The agent can handle the build steps. You still need to complete any macOS signing prompts, provider sign-in, and schedule setup yourself.

### Build manually

You need macOS 14 or later, Xcode with Swift 6.2 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen). Sign in to Claude Code or Codex CLI for the provider you want to use.

```sh
git clone https://github.com/24GUNV/wakebar.git
cd wakebar
brew install xcodegen
xcodegen generate
xcodebuild \
  -project Wakebar.xcodeproj \
  -scheme Wakebar \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Open `Wakebar.xcodeproj` in Xcode and run the Wakebar scheme, or use the local development scripts:

```sh
Scripts/setup_dev_signing.sh   # once; creates a local signing identity
Scripts/compile_and_run.sh
```

The scripts use a stable signing identity to keep Keychain permissions consistent across rebuilds. Set `WAKEBAR_DEVELOPMENT_TEAM` to use an Apple team identity instead.

## Set up a schedule

1. Open Wakebar from the menu bar.
2. Choose your wake time, weekdays, and how early to send the prompt.
3. Select Claude Code, Codex, or both, then follow the connection prompts and save.
4. Check that the selected providers show **Ready**.

If Codex asks you to run `codex login`, sign in and reopen the menu.

Opening the menu refreshes usage; it refreshes again every 60 seconds while open. **Start now** sends a prompt immediately and checks usage for confirmation. Wakebar tracks a successful request separately from a confirmed usage-window start.

## Credentials and privacy

After you explicitly connect each provider, Wakebar reads the Claude Code OAuth credential from macOS Keychain and the Codex CLI login from `~/.codex`. Claude credentials go to `api.anthropic.com`; Codex credentials go to `chatgpt.com`.

Wakebar has no server of its own. Schedules and usage data are not uploaded to a separate service, and provider secrets are not saved in Wakebar preferences. The app runs outside the App Sandbox so it can access the existing CLI credentials.

## Engineering and tests

The app uses SwiftUI and Swift concurrency. `WakebarCore` separates schedule calculation, persistence, and usage interpretation from the app's provider clients and views.

Tests cover schedule reconciliation after partial failures, duplicate prevention, daylight-saving changes, weekday rollover, and provider-confirmed usage transitions. CI parses Swift sources, runs tests, validates the packaging script, and builds an unsigned Release app.

```sh
find Sources Tests -name '*.swift' -print0 | xargs -0 -n 1 swiftc -frontend -parse
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/tmp/wakebar-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/wakebar-clang-cache \
  swift test --disable-sandbox --scratch-path /tmp/wakebar-swift-test
```

Live provider tests are opt-in and consume subscription usage. They require `WAKEBAR_LIVE_PROVIDER_TESTS=1` and a disposable schedule supplied through `WAKEBAR_LIVE_SCHEDULE_FILE`.

| Directory | Contents |
| --- | --- |
| `Sources/WakebarCore` | Scheduling, persistence, provider plans, and usage models |
| `Sources/WakebarApp` | macOS app, provider clients, and SwiftUI views |
| `Tests` | Core and app tests |
| `Scripts` | Build, signing, and packaging scripts |
| `Docs` | Integration details and release notes |

See [provider integration details](Docs/INTEGRATIONS.md) and the [release checklist](Docs/RELEASE_CHECKLIST.md). The packaging script supports Developer ID signing and notarization for a future downloadable release.

## License

[MIT](LICENSE).
