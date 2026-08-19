# Wakebar iPhone companion

## Current result

The iPhone companion can register a weekly wake alarm with AlarmKit on iOS 26. The alarm uses the system alert presentation and default sound. It does not use a countdown, so it does not need a Live Activity widget.

The companion asks for alarm access only after the user taps **Allow and set alarm**. It shows separate states for:

- no synced schedule;
- permission not requested;
- permission granted and ready to set;
- permission denied;
- alarm accepted by AlarmKit;
- alarm disabled;
- unsupported platform or scheduling failure.

Transient scheduling and cleanup failures show a retry action. Retry refreshes iCloud and reconciles the transaction journal before it reports success.

Add `NSAlarmKitUsageDescription` to the iPhone target. The value must explain why Wakebar creates alarms. AlarmKit cannot schedule an alarm when this value is missing or empty.

## Sync design

`PhoneAlarmSchedulePayload` is the versioned transfer object. The Mac publishes it to the user’s CloudKit private database. The iPhone fetches it at launch, when it returns to the foreground, and after a CloudKit background notification.

The iPhone stores the last valid schedule locally and associates it with the iCloud user record. If iCloud is temporarily unavailable for the same account, the interface labels this value **Saved copy** and shows the reason. Wakebar clears the copy and removes its installed alarm when the account changes or the active record disappears.

This slice supports device-local time only. AlarmKit relative schedules adjust when the iPhone time zone changes. The payload rejects a fixed-zone schedule instead of silently changing its meaning.

Use these identifiers:

- container: `iCloud.com.24gunv.wakebar`;
- record type: `WakeSchedule`;
- zone: `WakebarSchedules`;
- record name: `active-schedule`.

The schedule record has these fields:

- `payloadData`: encoded schedule data;
- `revisionSequence`: monotonic writer sequence;
- `modifiedAt`: writer modification date;
- `writerID`: stable writer identifier.

Wakebar stores one active schedule record. Publishing a new schedule replaces it. One Mac writer owns the record at a time. Its stable writer identifier and global sequence cover all schedule identities.

For one writer, resolve two versions in this order:

1. Select the greater revision sequence.
2. If equal, select the later modification date.

If the writer identifier changes, the new writer can take ownership only after it reads the current server record. Wakebar does not use the Mac wall clock to order two writers. A conditional-save conflict stops the takeover and requires a fresh publish. Do not run two Mac writers for one private database.

Wakebar retains CloudKit system fields and uses conditional saves. If another write from the same writer wins, Wakebar fetches that version, applies the sequence rules, and retries. It does not overwrite a newer server revision with `.allKeys`.

The iPhone registers a silent record-zone subscription that filters for `WakeSchedule`. Acknowledgement writes do not trigger this subscription. Wakebar migrates the earlier unfiltered subscription identifier when it starts. After AlarmKit accepts a new revision, the iPhone writes one `WakeScheduleAcknowledgement` record named `ack-<schedule UUID>`. It does not rewrite the record for an already confirmed revision. The record contains the schedule and alarm identifiers, revision fields, and confirmation date. The Mac can distinguish **iCloud updated** from **iPhone confirmed**.

The iPhone stores a transaction journal before it changes an alarm. The journal contains all managed alarm identifiers and the prior payload. It closes the process-termination gap between AlarmKit scheduling and local persistence. The app compares the journal with `AlarmManager.alarms` at launch and after AlarmKit updates. If the system alarm is missing, the interface offers **Set alarm again** instead of showing a stale confirmation. If replacement or cleanup fails, Wakebar restores the prior alarm when possible and keeps all unresolved identifiers for the next reconciliation.

## Reliability boundary

CloudKit sync is not an alarm transport. Apple states that the system can delay, drop, or combine background push notifications. A push indicates that changes might exist; the app must fetch changes from CloudKit.

The iPhone can alert while the Mac is off only after the iPhone receives the schedule and AlarmKit accepts it. The interface does not show **Alarm is set** until the local AlarmKit schedule call succeeds. A separate acknowledgement confirms this result to the Mac.

The Mac and iPhone targets use the same iCloud container. Silent CloudKit subscription delivery requires CloudKit, push notifications, and both **Background fetch** and **Remote notifications** background modes. These capabilities do not make delivery immediate. Test delayed sync, denied permissions, account changes, offline edits, time-zone changes, and revision conflicts on physical devices.

## Verification status

The `WakebarCore` target builds when the command selects the matching macOS 15.4 Command Line Tools SDK. The repository includes XCTest coverage for the pure components, failure recovery, and CloudKit record conversion. The full generated Xcode project still requires Xcode 26.

The available command-line tools do not include XCTest or the iOS 26 SDK. This machine therefore cannot execute those tests or type-check the AlarmKit branch. Conditional compilation with `os(iOS)` and `canImport(AlarmKit)` isolates the adapter.

The adapter uses the current iOS 26.1 alert initializer and an iOS 26.0 fallback. Run the iPhone target and tests with an Xcode installation that includes the iOS 26 SDK before release.

## Apple references

- [Scheduling an alarm with AlarmKit](https://developer.apple.com/documentation/AlarmKit/scheduling-an-alarm-with-alarmkit)
- [Wake up to the AlarmKit API](https://developer.apple.com/videos/play/wwdc2025/230/)
- [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)
- [CloudKit zone-subscription record filter](https://developer.apple.com/documentation/cloudkit/ckrecordzonesubscription/recordtype-1fuqo)
- [CloudKit remote records](https://developer.apple.com/documentation/cloudkit/remote-records)
- [CloudKit background mode requirements](https://developer.apple.com/documentation/cloudkit/ckdatabasesubscription)
