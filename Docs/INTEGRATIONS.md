# Provider integrations

Wakebar keeps the Claude and Codex paths independent. Each path uses provider-owned scheduling and provider-reported usage data.

## Shared schedule

The user selects a local morning time and weekdays. An optional five-hour repeat cadence applies only to Claude. Codex receives one task before each selected wake.

A fire starts a short cloud session on the user’s subscription. It consumes subscription usage, not API credit.

## Claude Code Routines

Wakebar synchronizes Claude Code Routines through `ClaudeRoutinesClient`. The client sends requests only to `api.anthropic.com`.

The integration performs these actions:

1. Read the current schedule-specific Routines.

2. Compare the provider state with the compiled plan.

3. Create missing Routines.

4. Update changed Routines.

5. Disable extra enabled Routines with the same Wakebar prefix.

Wakebar writes only when the comparison finds a change. If one create succeeds and a later create fails, the next list-and-diff pass recognizes the successful Routine and does not duplicate it.

### Claude Start now

Select **Start now** to run the managed Morning Routine. If the Routine does not exist, Wakebar synchronizes the compiled plan and then runs the new Morning Routine.

Wakebar shows **Requested** when the user starts this flow. A successful Routine response confirms only that Claude accepted the run request. Wakebar then checks Claude usage every 30 seconds for up to five minutes. It shows **Window started** only after provider data reports a later five-hour reset or increased five-hour usage.

Claude expects five-field cron expressions in Coordinated Universal Time (UTC). Wakebar synchronizes at app launch and once every 24 hours to correct daylight-saving-time drift. It also synchronizes when the resolved Claude access token changes.

Wakebar reads the Claude Code OAuth credential from macOS Keychain. If the credential JSON includes an expiry, the app shows when the token expires. Wakebar does not refresh the token. If authentication fails, sign in again in Claude Code by running `claude`.

Anthropic does not document the Claude Code Routines API. The integration can change without notice. Wakebar isolates all endpoint, header, and payload knowledge in `ClaudeRoutinesClient` so a provider change has a limited code surface.

## Codex scheduled tasks

Codex CLI does not provide the Scheduled management interface. You must create scheduled tasks in ChatGPT web.

Wakebar shows these values for every compiled task:

- the exact task name;

- the exact recurrence in local time;

- the time-zone identifier;

- the prompt `hi`;
- an instruction to keep the recurring task enabled after each run.

Select **Copy instructions** to copy paste-ready text. Open [chatgpt.com/scheduled](https://chatgpt.com/scheduled), create the task, and then select **I created the task** in Wakebar. Wakebar stores that confirmation with a timestamp.

The confirmation means only that the user says the task exists. A task is not a sent prompt. Wakebar does not claim that a scheduled fire occurred from the clock alone.

### Codex Start now

Codex does not provide a Routine run API. Select **Start now** to copy `hi` and open [chatgpt.com](https://chatgpt.com). The user must send the prompt.

Opening the page is not a sent prompt. Codex exposes a weekly limit, so Wakebar does not wait for or report a five-hour window change.

## Usage view

Wakebar refreshes usage when the menu opens and every 60 seconds while it remains open. Closing the menu cancels this refresh loop. The existing reader cache and maintenance cadence continue to control background provider calls.

For each selected provider, the menu shows:

- Claude five-hour, weekly, and Fable weekly usage;

- Codex weekly usage;

- an actionable sign-in instruction when authentication is unavailable.

The menu also shows one countdown to the next compiled provider-session event. Claude’s open five-hour window can govern this countdown. Codex’s weekly limit cannot.

## Security boundary

Wakebar reads the Claude Code OAuth token from macOS Keychain and Codex authentication from `~/.codex`. It sends credentials only to their provider:

- Claude credential → `api.anthropic.com`

- Codex credential → `chatgpt.com`

Wakebar does not upload credentials, schedules, or usage data to any other service. Provider secrets are not stored in the repository or Wakebar preferences.

## Confirmation rules

Wakebar uses these reporting rules throughout the app:

- A saved schedule is a plan, not a provider action.

- A created task is not a sent prompt.

- A Routine sync changes provider configuration and does not send the Routine prompt.

- A usage window starts only when provider data confirms a new window or increased usage.

- **Requested** identifies a user request without claiming that a provider sent a prompt or reset a window.
