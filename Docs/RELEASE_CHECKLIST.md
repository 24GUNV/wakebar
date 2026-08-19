# Wakebar release checklist

Complete this checklist with the same Apple development team on the Mac and iPhone targets.

## Signing and CloudKit

- Select the Wakebar development team in Xcode.

- Confirm that both app identifiers use `iCloud.com.24gunv.wakebar`.

- Enable CloudKit and push notifications for the iPhone target.

- Deploy the `WakebarSchedules` production schema before external distribution.

- Create a signed Release archive for each app.

## First-run test

- Install both apps while signed in to the same iCloud account.

- Confirm that the Mac opens with an unpublished draft.

- Save a schedule and verify that the Mac first shows **Awaiting iPhone**.

- Allow alarm access on the iPhone and confirm that both apps show the applied revision.

- Confirm that the app icon, permission copy, setup actions, and VoiceOver labels are correct.

## Alarm and delivery test

- Verify that the alarm rings and stops on a physical iPhone.

- Verify delivery while the companion runs in the background and after the user closes it.

- Test a delayed CloudKit update and the manual **Check iPhone now** action.

- Test an offline edit, then restore the network and confirm recovery.

- Deny alarm access, enable it later in Settings, and confirm recovery.

- Remove the system alarm and confirm that Wakebar offers to set it again.

- Change the iCloud account and confirm that Wakebar removes the old schedule and alarm.

- Change the system time zone and confirm that the alarm follows the device.

- Trigger a conflicting Mac write and confirm that Wakebar keeps the newer revision.

## Provider setup

- Create the Claude Code Routines from Wakebar’s copied setup text.

- Create the ChatGPT scheduled tasks from Wakebar’s copied setup text.

- Confirm the saved provider times in Wakebar.

- Verify that each provider creates only a fresh minimal `hi` session.

- Do not describe a successful prompt as proof that a five-hour or weekly usage window reset.
