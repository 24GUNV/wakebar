# Provider integrations

Wakebar keeps the Claude and Codex paths independent. Each path uses provider-owned scheduling and provider-reported usage data.

## Shared schedule

The user selects a local morning time and weekdays. An optional five-hour repeat cadence applies only to Claude. Codex receives one task before each selected wake.

A fire starts a short cloud session on the user’s subscription. It consumes subscription usage, not API credit.

## Claude Code Routines

Wakebar synchronizes Claude Code Routines through `ClaudeRoutinesClient`. The client sends requests only to `api.anthropic.com`.

The integration performs these actions:

1. Read every Routine whose name starts with `Wakebar ·`.

2. Compare the provider state with the compiled plan.

3. Create missing Routines.

4. Update changed Routines.

5. Delete every other `Wakebar ·` Routine, enabled or disabled, including Routines that an earlier schedule created under its own prefix. Wakebar never touches a Routine without that prefix.

Wakebar writes only when the comparison finds a change. If one create succeeds and a later create fails, the next list-and-diff pass recognizes the successful Routine and does not duplicate it.

### Every reset cadence

A Routine fires only on a cron expression, so the **Every reset** chain runs in the cloud as one extra Routine named `… Next reset`. After each Claude usage reading, Wakebar sets that Routine's cron expression to one minute after the open five-hour window resets, as a single UTC date and time. When the window reset moves, Wakebar rewrites the Routine. The fire happens on the provider, so it does not need the Mac to be awake.

Wakebar reads Claude usage every five minutes in the background while an enabled **Every reset** schedule includes Claude. If a reading finds no open window for 15 minutes after the planned fire, Wakebar deletes the `Next reset` Routine. The fixed Morning Routine then restarts the chain at the next selected wake.

### Claude Start now

Select **Start now** to run the managed Morning Routine. If the Routine does not exist, Wakebar synchronizes the compiled plan and then runs the new Morning Routine.

Wakebar shows **Requested** when the user starts this flow. A successful Routine response confirms only that Claude accepted the run request. Wakebar then checks Claude usage every 30 seconds for up to five minutes. It shows **Window started** only after provider data reports a later five-hour reset or increased five-hour usage.

Claude expects five-field cron expressions in Coordinated Universal Time (UTC). Wakebar synchronizes at app launch and once every 24 hours to correct daylight-saving-time drift. It also synchronizes when the resolved Claude access token changes.

Wakebar reads the Claude Code OAuth credential from macOS Keychain. Every read first uses the Apple `security` command. Claude Code writes the item with that command, and macOS lets the tool that created an item read it back without a consent dialog, whichever app runs the tool. This is the same read Claude Code makes at launch, and it survives Claude Code rewriting the item's access control list (ACL) on a token refresh. If the command fails, a user-initiated read falls back to the Security framework and may show the consent dialog. A background read falls back with keychain interaction disabled process-wide, so it fails quietly instead. An `LAContext` with `interactionNotAllowed` does not suppress the login keychain dialog; securityd still displays the prompt. If the credential JSON includes an expiry, the app shows when the token expires. Wakebar does not refresh the token. If authentication fails, sign in again in Claude Code by running `claude`.

Anthropic does not document the Claude Code Routines API. The integration can change without notice. Wakebar isolates all endpoint, header, and payload knowledge in `ClaudeRoutinesClient` so a provider change has a limited code surface.

## Codex wake

OpenAI does not offer a scheduled Codex run that opens the usage window, and a ChatGPT scheduled task counts against a separate ChatGPT meter. Wakebar therefore wakes Codex from this Mac.

A wake is one request to `POST https://chatgpt.com/backend-api/codex/responses`, the endpoint Codex CLI uses for a turn. The request carries the Codex CLI access token and account id from `~/.codex/auth.json`, the model from `~/.codex/config.toml`, the instructions `Reply only with hi. Do not use tools.`, the input `hi`, no tools, and low reasoning effort. It streams until the provider reports `response.completed`. A September 5, 2026 live test measured about five input tokens per request.

Wakebar does not run `codex exec`. A Codex CLI turn loads the coding-agent context and can consume substantial usage even for a one-word prompt.

### When Codex wakes

- **Before each wake**: one request at the lead time before each selected morning slot.

- **Every reset**: one request after each reset of the limit Codex reports. On a plan with a five-hour window, the requests chain off that window. On a weekly-only plan, one request follows the weekly reset.

The wake runs only while Wakebar is open. Wakebar checks the plan at launch, when the Mac wakes from sleep, and at least every 30 minutes. A slot the Mac slept through is sent on wake when the window is still closed, and settled without a request when the window is already open. Wakebar records the last handled slot in preferences so a relaunch does not send it twice.

Wakebar reads usage before and after each request and reports **Window started** or **Week started** only when the provider's reading changes: increased usage, a later reset, or an idle placeholder that pins to a real reset. Codex reports an idle limit as a full, unused window whose reset keeps pace with the clock.

### Codex Start now

Select **Start now** to send the same request immediately. Wakebar then polls usage and reports the started window when the provider confirms it.

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

- A Codex request that returns `response.completed` is a sent prompt, but the window counts as started only when the next usage reading confirms it.

- **Requested** identifies a user request without claiming that a provider sent a prompt or reset a window.
