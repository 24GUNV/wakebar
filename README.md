# Wakebar

Wakebar is a native macOS menu-bar app for Claude Code and Codex users. Set a morning time and weekdays before bed. Wakebar then schedules a minimal prompt for each provider and reports the limits each provider exposes.

Setup is automatic for both providers. Claude wakes from a cloud Routine. Codex wakes from this Mac while Wakebar is open. The menu shows Claude five-hour, weekly, and Fable weekly usage. It shows Codex weekly usage without inventing a five-hour window.

![Wakebar menu overview](Docs/Images/wakebar-overview.svg)

## How it works

![Wakebar provider flow](Docs/Images/wakebar-flow.svg)

Wakebar compiles one local schedule into two provider-specific plans:

- Claude: Wakebar lists existing Routines and writes only the changes required for the compiled plan.

- Codex: Wakebar sends one minimal Codex request from this Mac at each planned wake. It signs the request with the Codex CLI credential and uses the model from `~/.codex/config.toml`.

- Usage: Wakebar reads Claude’s five-hour, weekly, and Fable weekly limits and Codex’s weekly limit.

- Repeats: The optional five-hour repeat cadence applies only to Claude; Codex receives one request before each selected wake, or one after each reset on the **Every reset** cadence.

A planned wake is not a sent prompt. A Claude prompt is sent only when the Routine fires. A Codex prompt is sent only when Wakebar is running at the planned time, or when the Mac wakes and the window is still closed. Wakebar does not report that a usage window started unless provider usage data confirms the change.

A September 5, 2026 live test confirmed that one minimal Codex request pins the reported limit. Codex reports a weekly limit on some plans, so Wakebar does not assume a five-hour Codex window.

## Cost of a fire

Each fire starts a short cloud session on the connected subscription. It consumes subscription usage. It does not use Anthropic or OpenAI API credits.

The minimal prompts are:

- Claude Code Routine: `Reply only with hi. Do not use tools, edit files, publish artifacts, or request permissions.`

- Codex request: `Reply only with hi. Do not use tools.` with the prompt `hi`, no tools, and low reasoning effort.

## Requirements

- macOS 14 or later

- Xcode with Swift 6.2 or later

- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

- Claude Code signed in with Claude.ai

- Codex CLI signed in with ChatGPT

Wakebar is a direct-download, notarized, non-sandboxed app. The non-sandboxed build can read the existing local command-line credentials that the providers own.

## Install

There is no packaged release yet. Until the first release appears on [GitHub Releases](https://github.com/24GUNV/wakebar/releases), follow **Build from source** below.

When a release is available:

1. Download the latest notarized `.dmg` from [GitHub Releases](https://github.com/24GUNV/wakebar/releases).

2. Open the disk image and drag Wakebar to Applications.

3. Open Wakebar from Applications.

Gatekeeper verifies the Developer ID signature and notarization ticket. Do not bypass Gatekeeper. If verification fails, delete the download and get a new copy from GitHub Releases.

## Build from source

```sh
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

The live provider test is opt-in because it fires a real Claude Routine and consumes subscription usage:

```sh
WAKEBAR_LIVE_PROVIDER_TESTS=1 \
WAKEBAR_LIVE_SCHEDULE_FILE=/path/to/disposable-schedule.json \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
swift test --disable-sandbox --filter LiveProviderAcceptanceTests
```

For a signed local development build, create the local signing identity once,
then build and run:

```sh
Scripts/setup_dev_signing.sh   # once; creates the "Wakebar Dev Signing" identity
Scripts/compile_and_run.sh
```

Wakebar reads the Claude Code credential through the `security` command,
which macOS lets read the item without a consent dialog, so a normal run
never asks for Keychain access. Debug builds still sign with that fixed
identity so that, if the command fails and the app falls back to the
Security framework, a macOS Keychain "Always Allow" grant survives rebuilds.
An ad-hoc or unsigned build changes identity on every rebuild and macOS asks
again each time. To sign with an Apple team identity instead, set
`WAKEBAR_DEVELOPMENT_TEAM`.

## Set up Wakebar

1. Open Wakebar from the menu bar.

2. Set the morning time and weekdays.

3. Select Claude Code, Codex, or both.

4. Save the schedule.

5. Open Claude setup and synchronize the Routines.

6. Open Codex setup and confirm that the sign-in row shows **Codex CLI**. If it shows **Run `codex login`**, sign in and reopen the menu.

## Usage and Start now

Open the menu to refresh usage immediately. Wakebar refreshes it every 60 seconds while the menu stays open. Closing the menu stops this refresh loop.

Claude shows five-hour, weekly, and Fable weekly usage. Codex shows weekly usage. If authentication is missing, the row shows the command that restores sign-in.

Select **Start now** for an immediate request:

- Claude runs the managed Morning Routine and synchronizes it first if necessary.

- Codex sends the minimal request from this Mac.

For both providers, Wakebar reads usage every 30 seconds for up to five minutes. **Window started** appears only after the provider confirms a new five-hour window. **Week started** appears when Codex reports only a weekly limit and that limit pins to the request.

## Claude schedule maintenance

Claude cron expressions use Coordinated Universal Time (UTC). Wakebar synchronizes Routines at launch, once every 24 hours, and when the resolved Claude access token changes. This process corrects daylight-saving-time drift.

A sync owns every Routine named `Wakebar ·`. It deletes Routines that an earlier schedule created, so a replaced schedule cannot keep firing and the provider list stays clean.

With the **Every reset** cadence, Wakebar keeps one extra `Next reset` Routine pinned to one minute after the open five-hour window resets. Wakebar reads Claude usage every five minutes in the background and rewrites that Routine when the reset moves. The Routine fires in the cloud, so the Mac does not need to be awake.

Anthropic does not document the Claude Code Routines API. Wakebar isolates this integration in `ClaudeRoutinesClient`. If the provider changes the API, the rest of the scheduling and persistence code remains independent.

## Security

Wakebar reads only these existing credentials:

- the Claude Code OAuth credential from macOS Keychain;

- Codex authentication from `~/.codex`.

Wakebar sends the Claude credential only to `api.anthropic.com`. It sends the Codex credential only to `chatgpt.com`. Wakebar does not upload credentials or usage data anywhere else. It does not store provider secrets in the repository or in Wakebar preferences.

## Verification

Run the local checks:

```sh
xcodegen generate
find Sources Tests -name '*.swift' -print0 | xargs -0 -n 1 swiftc -frontend -parse
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=/tmp/wakebar-clang-cache \
  SWIFTPM_MODULECACHE_OVERRIDE=/tmp/wakebar-clang-cache \
  swift test --disable-sandbox --scratch-path /tmp/wakebar-swift-test
xcodebuild \
  -project Wakebar.xcodeproj \
  -scheme Wakebar \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Repository structure

```text
Sources/WakebarCore      Scheduling, provider plans, persistence, and usage models
Sources/WakebarApp       macOS app, provider clients, shared state, and SwiftUI views
Tests/WakebarTests       Deterministic core tests
Tests/WakebarAppTests    Deterministic client, reconciliation, and UI-layout tests
Scripts                  Local build and packaging scripts
Docs                     Integration and release notes
```

See [integration details](Docs/INTEGRATIONS.md) and the [release checklist](Docs/RELEASE_CHECKLIST.md).

The release packaging script creates `Wakebar.dmg` and `Wakebar.dmg.sha256` after signing and notarization succeed.
