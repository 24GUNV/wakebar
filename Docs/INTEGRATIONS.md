# Provider and alarm integrations

Wakebar treats a scheduled event, a sent prompt, and a refreshed usage window as separate results. The interface must not show a later result until Wakebar receives evidence for it.

## Claude Code

Claude Code Routines run on Anthropic infrastructure. They can run while the Mac is off. Wakebar starts the supported interactive `/schedule` workflow through the locally installed Claude Code command-line interface (CLI). Claude asks the user to review the combined change before it saves.

Wakebar includes three building blocks:

- A CLI preflight that checks Claude Code 2.1.227 or later and Claude.ai sign-in.
- A reconciliation request with schedule-specific Routine names. It asks Claude to create missing Routines, update matching Routines, and disable obsolete matching Routines.
- An adapter that starts an existing Routine through the experimental trigger API after the user stores its token locally.

The `/schedule` workflow is conversational and is not an atomic or independently verified API operation. The user must check Claude’s proposed changes and resulting Routine links before marking setup complete. Wakebar does not read Claude credentials or call Anthropic’s private Routine interfaces. The CLI handoff uses the first-party Claude Code session. The optional trigger adapter accepts only Anthropic HTTPS trigger URLs. It does not upload tokens to a Wakebar service or retry automatically because the trigger API does not provide an idempotency key.

Official references: [Claude Code Routines](https://code.claude.com/docs/en/routines) and [Routine trigger API](https://platform.claude.com/docs/en/api/claude-code/routines-fire).

## Codex

Wakebar’s first release uses a hosted ChatGPT scheduled task. This route can run while the Mac is off, but it cannot use a local project folder.

The shared core also describes desktop, local `codex exec`, and always-on runner capabilities for later work. The current interface does not let the user select or confirm those unimplemented routes.

OpenAI documentation does not confirm that a small scheduled prompt starts or resets a Codex subscription window. Wakebar therefore labels this result as unverified until an account-level test confirms it.

Official references: [Scheduled tasks](https://learn.chatgpt.com/docs/automations?surface=app) and [non-interactive Codex](https://learn.chatgpt.com/docs/non-interactive-mode).

## iPhone alarm

The iPhone companion schedules the alarm locally with AlarmKit. The system can then present the alarm when the companion app is not running. AlarmKit requires user authorization and iOS 26 or later.

The Mac publishes one versioned active schedule to the user’s private CloudKit database. Conditional saves reject stale concurrent writes. The phone fetches the record at launch, in the foreground, and after a background change notification. It keeps an account-scoped local copy for temporary network failures and removes that copy after an account change.

At launch, the companion registers this iPhone with Apple Push Notification service. The interface reports APNs device registration and the saved CloudKit subscription as separate states. The app can also refresh in the foreground or after a manual request.

Wakebar tracks CloudKit delivery, AlarmKit authorization, the installed alarm revision, and the phone acknowledgement separately. The phone reconciles its saved revision with AlarmKit and reports a removed alarm instead of retaining a stale **Alarm is set** state.

The phone writes an acknowledgement only after it applies the revision or confirms an alarm-off revision. The Mac can therefore distinguish **iCloud updated** from **iPhone confirmed**.

Background CloudKit delivery is not guaranteed or immediate. The phone must receive and apply the schedule before the Mac turns off. The AlarmKit and CloudKit paths still require Xcode, iOS 26, and physical-device verification before release.

Official references: [Schedule an AlarmKit alarm](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit) and [background notification limits](https://developer.apple.com/documentation/usernotifications/pushing-background-updates-to-your-app).
