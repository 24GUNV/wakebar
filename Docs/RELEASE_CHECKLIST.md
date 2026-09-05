# Release checklist

Use this checklist for a direct-download, notarized macOS release.

## Version and source

- Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `Configurations/Common.xcconfig`.

- Confirm that the deployment target is macOS 14 or later.

- Confirm that the build enables Swift 6.2 strict concurrency.

- Confirm that the worktree contains only intended release changes.

## Generated project and tests

- Run `xcodegen generate`.

- Run the Swift parse check.

- Run `swift test` with a fresh module cache and scratch path.

- Build the unsigned macOS Release configuration.

- Confirm that continuous integration uses a macOS runner with Xcode 26.

- Confirm that continuous integration uses fresh module-cache, scratch, and DerivedData paths.

- Confirm that the SwiftPM cache contains downloaded artifacts only.

- Confirm that the workflow does not cache compiler module output.

- Confirm that all deterministic tests pass.

- Review skipped tests and run opt-in visual snapshots when the layout changed.

- Regenerate the README menu pictures when the popover layout changed. Run `WAKEBAR_SNAPSHOT_DIR=/tmp/wakebar-snaps swift test --filter PopoverSnapshotTests` with `DEVELOPER_DIR` set to Xcode, then copy `menu-dark.png` and `menu-light.png` to `Docs/Images/wakebar-menu-dark.png` and `Docs/Images/wakebar-menu-light.png`.

- Run `LiveProviderAcceptanceTests` with `WAKEBAR_LIVE_PROVIDER_TESTS=1` and `WAKEBAR_LIVE_SCHEDULE_FILE` set to a disposable Wakebar schedule file.

- Confirm that the live test fires the managed Claude Routine and receives provider-reported usage confirmation within five minutes.

- Confirm that the live Codex read returns the signed-in account's weekly usage window.

## Scope check

- Confirm that the app contains only the macOS target.

- Confirm that both provider setup screens request explicit connection consent before reading credentials.

- Confirm that no Codex CLI task-management code is present and that Wakebar never runs `codex exec`.

- Confirm that Claude synchronizes at launch, on Mac wake, on time-zone changes, and when a maintenance check finds a changed upcoming plan or access token.

## Claude acceptance

- Sign in through Claude Code.

- Save a schedule and synchronize Routines.

- Confirm that names, UTC cron expressions, enabled states, and prompts match the compiled plan.

- Synchronize again and confirm that Wakebar performs no writes when the plan has no changes.

- Change the local time zone across a daylight-saving boundary and confirm that the next synchronization corrects the UTC cron value.

- Reject the credential and confirm that the app says: **Sign in again in Claude Code (run `claude`)**.

- If the credential has an expiry, confirm that the status shows the relative expiry time.

## Codex acceptance

- Confirm that the setup view shows **Codex CLI** as the sign-in when `~/.codex/auth.json` is present.

- Reject Codex authentication and confirm that the app says: **Run `codex login`** and the menu row shows **Needs setup**.

- Set an **Every reset** schedule with an idle Codex limit and confirm that Wakebar sends one request, then shows **Week started** or **Window started** after the next reading.

- Confirm that a second check inside ten minutes does not send another request.

- Sleep the Mac through a **Before each wake** slot with the window closed, wake it, and confirm that Wakebar sends the missed request once.

- Relaunch Wakebar and confirm that the handled slot is not sent again.

## Usage and Start now acceptance

- Open the menu and confirm that usage refreshes immediately.

- Keep the menu open for more than 60 seconds and confirm that the values refresh.

- Close the menu and confirm that Wakebar does not continue the 60-second refresh loop.

- Confirm that Claude shows five-hour, weekly, and Fable weekly bars when the provider returns them.

- Confirm that Codex shows one weekly bar and no five-hour bar.

- Remove the managed Morning Routine and select Claude **Start now**.

- Confirm that Wakebar synchronizes the missing Routine before it requests a run.

- Select Codex **Start now**.

- Confirm that Wakebar sends one request to `chatgpt.com/backend-api/codex/responses` and shows **Requested**.

- Confirm that Wakebar reports **Window started** or **Week started** only after the usage reading changes.

- Confirm that Claude shows **Requested** before usage confirmation.

- Confirm that **Window started** appears only after provider data changes.

- Confirm that unchanged Claude usage becomes **Requested; not confirmed** after five minutes.

## Security and network

- Confirm that no secret is present in source files, generated project files, logs, or test fixtures.

- Confirm that Claude credentials are read from macOS Keychain.

- Confirm that Codex authentication is read from `~/.codex`.

- Confirm that credential-bearing requests go only to `api.anthropic.com` or `chatgpt.com`.

- Confirm that the app does not upload schedules or usage data elsewhere.

## Signing, notarization, and disk image

- Store the Developer ID Application certificate in the signing Keychain.

- Store the notarytool credentials in a Keychain profile.

- Set `WAKEBAR_DEVELOPMENT_TEAM` to the Apple Developer team identifier.

- Set `WAKEBAR_DEVELOPER_ID_APPLICATION` to the full Developer ID Application identity.

- Set `WAKEBAR_NOTARY_PROFILE` to the notarytool Keychain profile name.

- Run `Scripts/package_app.sh --dry-run` and inspect each command.

- Run `Scripts/package_app.sh` to build a universal Release app and disk image.

- Confirm that the script validates the Developer ID identity and notarytool profile before it builds.

- Confirm that the app contains `arm64` and `x86_64` slices.

- Confirm that the app uses the hardened runtime and the non-sandboxed release entitlements.

- Confirm that `notarytool` accepted the disk image.

- Confirm that `Scripts/package_app.sh` stapled the notarization ticket to the disk image.

- Confirm that the script created `Wakebar.dmg.sha256` and verified it successfully.

- Run `codesign --verify --deep --strict --verbose=2`.

- Run `spctl --assess --type execute --verbose=2`.

- Test the downloaded artifact on a clean macOS 14 or later system.

- Confirm that **Check for updates** opens `https://github.com/24GUNV/wakebar/releases`.

- Confirm that the menu shows the expected bundle version.

## Final release check

- Confirm that the documentation describes a fire as subscription usage, not API credit.

- Confirm that the undocumented Claude Routines API warning is visible in the documentation.

- Confirm that the documentation describes Codex window behavior as measured, not assumed.

- Publish `Wakebar.dmg.sha256` with the direct-download artifact.

## Release boundaries

- Confirm a first launch cannot read either provider credential before connection consent.
- Decline Keychain authorization and verify that no alternate credential-reading process runs.
- Simulate usage-read outages: no automatic Codex requests and no deletion of Claude's last reset Routine.
- Verify the signing script selects only the Wakebar private key. Test it with a disposable Keychain containing an unrelated signing key.
- Inspect the Release executable for LLVM coverage instrumentation; it must be absent.
- Verify the signed and notarized download on a clean Mac before offering a packaged release.
