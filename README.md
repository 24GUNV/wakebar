# Wakebar

Wakebar is a native macOS menu-bar app for Claude Code and Codex users. Set a morning time and weekdays before bed. Wakebar then coordinates provider-hosted prompts and reports the limits each provider exposes.

Claude setup is automatic. Codex setup uses a ChatGPT scheduled task that you create from Wakebar’s exact instructions. The menu shows Claude five-hour, weekly, and Fable weekly usage. It shows Codex weekly usage without inventing a five-hour window.

![Wakebar menu overview](Docs/Images/wakebar-overview.svg)

## How it works

![Wakebar provider flow](Docs/Images/wakebar-flow.svg)

Wakebar compiles one local schedule into two provider-specific plans:

- Claude: Wakebar lists existing Routines and writes only the changes required for the compiled plan.

- Codex: Wakebar supplies exact task instructions for you to use at [chatgpt.com/scheduled](https://chatgpt.com/scheduled).

- Usage: Wakebar reads Claude’s five-hour, weekly, and Fable weekly limits and Codex’s weekly limit.

- Repeats: The optional five-hour repeat cadence applies only to Claude; Codex receives one scheduled task before each selected wake.

Creating a scheduled task is not the same as sending a prompt. A prompt is sent only when the provider runs a scheduled fire. Wakebar does not report that a usage window started unless provider usage data confirms the change.

An August 24, 2026 live test confirmed that the ChatGPT task fired. Codex reports a weekly limit, so Wakebar does not test or display a five-hour Codex window.

## Cost of a fire

Each fire starts a short cloud session on the connected subscription. It consumes subscription usage. It does not use Anthropic or OpenAI API credits.

The minimal prompts are:

- Claude Code Routine: `Reply only with hi. Do not use tools, edit files, publish artifacts, or request permissions.`

- ChatGPT scheduled task: reply only with `hi`, and keep the recurring task enabled after every run.

## Requirements

- macOS 14 or later

- Xcode with Swift 6.2 or later

- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

- Claude Code signed in with Claude.ai

- Codex signed in with ChatGPT

- ChatGPT scheduled tasks available for the account

Wakebar is a direct-download, notarized, non-sandboxed app. The non-sandboxed build can read the existing local command-line credentials that the providers own.

## Install

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

For a signed local development build, create the local signing identity once,
then build and run:

```sh
Scripts/setup_dev_signing.sh   # once; creates the "Wakebar Dev Signing" identity
Scripts/compile_and_run.sh
```

Debug builds sign with that fixed identity so the macOS Keychain
"Always Allow" grant for the Claude Code credential survives rebuilds. An
ad-hoc or unsigned build changes identity on every rebuild and macOS asks
again each time. To sign with an Apple team identity instead, set
`WAKEBAR_DEVELOPMENT_TEAM`.

## Set up Wakebar

1. Open Wakebar from the menu bar.

2. Set the morning time and weekdays.

3. Select Claude Code, Codex, or both.

4. Save the schedule.

5. Open Claude setup and synchronize the Routines.

6. Open Codex setup and select **Copy instructions**.

7. Open [chatgpt.com/scheduled](https://chatgpt.com/scheduled) and create each listed task.

8. Return to Wakebar and select **I created the task**.

## Usage and Start now

Open the menu to refresh usage immediately. Wakebar refreshes it every 60 seconds while the menu stays open. Closing the menu stops this refresh loop.

Claude shows five-hour, weekly, and Fable weekly usage. Codex shows weekly usage. If authentication is missing, the row shows the command that restores sign-in.

Select **Start now** for an immediate request:

- Claude runs the managed Morning Routine and synchronizes it first if necessary.

- Codex copies `hi` and opens [chatgpt.com](https://chatgpt.com) for the user to send the prompt.

For Claude, Wakebar reads usage every 30 seconds for up to five minutes. **Window started** appears only after Claude confirms a new five-hour window. Codex has no equivalent five-hour check.

## Claude schedule maintenance

Claude cron expressions use Coordinated Universal Time (UTC). Wakebar synchronizes Routines at launch, once every 24 hours, and when the resolved Claude access token changes. This process corrects daylight-saving-time drift.

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
