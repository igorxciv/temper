# Heart-rate zones on a watchOS 26 Watch

Research for [Where can a Watch app on watchOS 26 get a maximum and a resting heart rate to work out heart-rate zones, and how does Apple split its zones?](https://github.com/igorxciv/temper/issues/117) on the [Watch app map](https://github.com/igorxciv/temper/issues/100). Sources were read on 2026-11-08. Nothing here has been run on a device. The last section lists what only a device test can settle.

The owner's Series 8 stays on watchOS 26.5, and the Watch target deploys to watchOS 26. The iPhone runs iOS 27, and the iPhone target deploys to iOS 27.0. [How should each of the Watch's screens look, and which heart-rate reading goes in the slot?](https://github.com/igorxciv/temper/issues/111) put a five-bar zone meter beside the bpm. [What does a Watch-saved Health workout look like next to the iPhone's own?](https://github.com/igorxciv/temper/issues/108) measured one HealthKit grant shared by the iPhone and Watch apps, reads included. This file surfaces facts only. Choosing the zone method is the job of [How does Temper work out the heart-rate zone the Watch shows?](https://github.com/igorxciv/temper/issues/118).

## Answer

- **How Apple splits its zones: five zones from a maximum and a resting rate. The exact formula isn't published.** Apple says the zones "are a percentage of your maximum heart rate and are automatically calculated and personalized using your health data" (Support). The watchOS 9 release notes say the view "uses max and resting heart rate to create personalised zones" (Support). WWDC26 says they're calculated "by considering one's age and resting heart rate" (WWDC). Only zones 2, 3 and 4 can be edited by hand (Support). Apple publishes no percentages. Users report that the Watch's settings page names the heart-rate reserve method, and one posted set of zones fits reserve cutoffs at 60, 70, 80 and 90% to within 2 bpm (Report, worked below). Those are the prototype's numbers.
- **Without data:** with no date of birth in Health, the Watch calculates no zones at all (Support). What Apple uses with no resting rate, and how it gets the maximum (an age formula or the highest observed rate), is unpublished (Unconfirmed). One report says both values update on the first of each month (Report).
- **Reading the owner's maximum or zones from Settings: not on watchOS 26.** HealthKit has no maximum-heart-rate type (SDK). Every zone symbol is marked watchOS 27 and iOS 27, and calling one at a watchOS 26 target fails to compile (SDK, Tested). On iOS and watchOS 27, `HKHealthStore.preferredWorkoutZoneConfiguration(for:)` returns the zones the person set in Health Settings, or the system's zones (Doc). It returns zone boundaries, not the maximum or resting values behind them (Doc, SDK). **The iPhone runs iOS 27, so the iPhone app can read the preferred zones and send their boundaries to the Watch** (Tested, compiles at iOS 27.0). Apple says preferred zones "sync across devices via HealthKit" (WWDC). Whether a Series 8 on watchOS 26 feeds its own zone setting into that sync is undocumented (Unconfirmed).
- **HealthKit inputs: date of birth and resting heart rate, read on the Watch.** Read `HKCharacteristicType(.dateOfBirth)` with `dateOfBirthComponents()` (Doc). Read `HKQuantityType(.restingHeartRate)` by taking the newest sample (Doc). Both are read-only asks under the existing `NSHealthShareUsageDescription`. Both compile on watchOS 26 (Tested), and every device has its own store that HealthKit syncs (Doc). Denied and missing look the same: no value (Doc). Because the grant is shared, the iPhone's request can include these two types and the Watch then won't prompt (Measured for heart rate in the Watch-saved workout probe, Inferred for these). For an observed maximum, the app could also take the highest `heartRate` sample, but old data is purged from the Watch (Doc).
- **watchOS 27's zone APIs:** you read the preferred configuration, or set a custom one on the builder before `beginCollection`. The live builder then sends `workoutBuilder(_:didUpdateWorkoutZone:)` when the zone changes, with the current and previous zone and the time spent in each. The saved `HKWorkout` and each `HKWorkoutActivity` carry `zoneGroupsByType`. A configuration needs 3 to 9 zones: the first starts at 0 and the last is unbounded. It covers heart rate and cycling power (Doc, SDK, WWDC). Moving to it later means handing HealthKit the same boundaries Temper computes and dropping Temper's own zone lookup (Inferred).

## How to read the labels

| Label | Meaning |
|---|---|
| **Doc** | Apple developer documentation, read from the site's JSON data. |
| **Support** | An Apple Support article or Apple's release notes. |
| **SDK** | Headers and Swift interfaces in Xcode 27.2 (watchOS 27.2 SDK). |
| **WWDC** | An Apple WWDC session transcript. |
| **Report** | A developer, press or user report. Not an Apple source. |
| **Measured** | Measured on the owner's devices in an earlier ticket. |
| **Tested** | Typechecked on this Mac with `xcrun --sdk watchos swiftc -typecheck -target arm64_32-apple-watchos26.0 -swift-version 6 -warnings-as-errors` (or `--sdk iphoneos`, `-target arm64-apple-ios27.0`). Nothing was run. |
| **Inferred** | My conclusion. No source states it. |
| **Unconfirmed** | I looked and found no source. |

## 1. How Apple's Workout app sets its five zones

### What Apple says

- **Support (current guide, watchOS 26 and 27):** "Heart Rate Zones are a percentage of your maximum heart rate and are automatically calculated and personalized using your health data." "Heart Rate Zones are calculated only if you've entered your date of birth in the Health app on your iPhone." "By default, Heart Rate Zones are calculated for you based on your health data, but you can manually edit those zones." To edit: Settings › Workout › Heart Rate Zones on the Watch, or My Watch › Workout › Heart Rate Zones in the iPhone's Watch app, then "Tap Manual, tap zone 2, 3, or 4, then enter lower and upper limits." Zones show in cardio workouts ([View Heart Rate Zones][support-zones]; the [watchOS 9 version][support-zones-9] says the same).
- **Support (watchOS 9.0 release notes):** "Heart Rate Zones view uses max and resting heart rate to create personalised zones and shows time spent in each zone" ([About watchOS 9 Updates][watchos9-notes]).
- **Newsroom (June 2022):** "Heart Rate Zones, which can be manually created or automatically calculated using personalized Health data, can be used to monitor the intensity of a workout" ([watchOS 9 announcement][newsroom-9]).
- **WWDC26 207:** "Heart rate zones are a training resource that's personalized to an individual. They are calculated by considering one's age and resting heart rate." And: "These zones are periodically calculated, based on user metrics, if available" ([WWDC26 207][wwdc26]).
- **Doc:** "System-generated zones update periodically as the person's health metrics change, however, the system preserves zones that the person configures" ([preferredWorkoutZoneConfiguration(for:)][doc-preferred]).

So Apple documents five zones, built from a maximum and a resting rate, needing a date of birth, recalculated periodically, with 2 to 4 editable. "Percentage of your maximum" and "uses max and resting heart rate" fit the heart-rate reserve method, where a boundary is resting + p × (maximum − resting). Apple never names the method or its percentages in a developer or support source (Unconfirmed).

### What users report

- **Report:** in a 2022 thread, users say the Watch's Heart Rate Zones settings page names the heart-rate reserve method ("Even says it there on the settings page!"). One poster gave resting 42 and maximum 184, with zone 2 from 127, zone 3 from 141, zone 4 from 155 and zone 5 from 168 ([MacRumors thread][macrumors]).
- **Inferred from that report:** the reserve is 184 − 42 = 142. At 60, 70, 80 and 90% the boundaries are 127.2, 141.4, 155.6 and 169.8. The first three match when rounded down, and the fourth is within 2 bpm. That supports reserve cutoffs at 60/70/80/90%, the prototype's values. It's one person's numbers, not a published rule.
- **Report (9to5Mac, 2024):** Apple "automatically create[s] your five heart rate zones based on the Heart Rate Reserve method. Max and resting values are updated automatically on the first day of each month." It cites Apple's support page, which says neither thing ([9to5Mac][9to5mac]).
- **Report (Tom's Guide):** gives the maximum as 220 minus age, with zones as percentages of the maximum. That conflicts with the reserve reports ([Tom's Guide][tomsguide]).
- **Inferred, weak:** Apple's `HKWorkoutZone` page gives an example zone of "136.8 to 147.6 beats per minute" ([HKWorkoutZone][doc-zone]). That is 10.8 bpm wide, which is 10% of a 108 bpm reserve. It's only an illustration, but it fits 10% reserve steps.

### When data is missing

- **No date of birth:** "Heart Rate Zones are calculated only if you've entered your date of birth" (Support). The Watch then shows no automatic zones. What the zone view shows instead isn't documented (Unconfirmed).
- **No resting rate:** not documented (Unconfirmed). A Watch worn rarely may have no recent resting-rate sample.
- **How Apple gets the maximum:** not documented. An age formula, the highest observed rate, or a mix are all possible (Unconfirmed). The reports disagree.

## 2. Can a third-party app read the maximum or the zones from Settings?

### watchOS 26: no

- **SDK:** the characteristic types are activity move mode, biological sex, blood type, date of birth, Fitzpatrick skin type and wheelchair use (`HKTypeIdentifiers.h`). No quantity or characteristic type holds a maximum heart rate. A grep of the headers and Swift interface for "maximumHeartRate" or "MaxHeartRate" finds nothing. Heart-rate recovery and VO2 max types exist, and so does recovery metadata such as `HKMetadataKeyHeartRateRecoveryMaxObservedRecoveryHeartRate`, but nothing for the zone setting.
- **SDK:** every zone symbol in the HealthKit Swift interface is marked `@available(anyAppleOS 27.0, *)`, or iOS 27.0 and watchOS 27.0 for `HKLiveWorkoutZoneUpdate` (`arm64_32-apple-watchos.swiftinterface`, `HKLiveWorkoutZoneUpdate.h`).
- **Tested:** `preferredWorkoutZoneConfiguration(for:)` at a watchOS 26.0 target fails with "is only available in watchOS 27.0 or newer".
- **Inferred:** the Watch's Settings › Workout › Heart Rate Zones values aren't exposed to apps on watchOS 26 by any API. Nor are the maximum and resting values the system used.

### watchOS 27 and iOS 27: the zones, not the maximum

- **Doc:** `preferredWorkoutZoneConfiguration(for:)` "Returns a person's preferred zone configuration for a quantity type", or `nil` "if the person hasn't configured zones for the quantity type". "The system returns the person's manually configured zones from Health Settings, or the system-generated zones if the person hasn't set custom values" ([doc-preferred]).
- **Doc, SDK:** an `HKWorkoutZoneConfiguration` holds `zones` (each `HKWorkoutZone` has an `index`, an optional `minimum` and an optional `maximum`) and a `source` of `.system`, `.user` or `.app` ([HKWorkoutZoneConfiguration][doc-config]). WWDC26: "The first zone starts at 0 and the last is unbounded."
- **Inferred:** the configuration gives boundaries only. The maximum and resting values behind system zones aren't exposed. The top boundary (start of zone 5) is the most you can get.
- **WWDC26:** "Before accessing workout zone data, request HealthKit authorization for the relevant quantity types. In this case workouts, heart rate, and cycling power." Temper's shared grant already includes reading heart rate (Measured, [What does a Watch-saved Health workout look like next to the iPhone's own?](https://github.com/igorxciv/temper/issues/108)).
- **WWDC26:** "By default, HealthKit uses the preferred workout zone thresholds, configured in Health Settings. With preferred zones, people receive a consistent experience across apps and devices, since these zones sync across devices via HealthKit."

### The iPhone as the reader

- **Tested:** `preferredWorkoutZoneConfiguration(for: HKQuantityType(.heartRate))` typechecks at an iOS 27.0 target. Temper's iPhone app deploys to iOS 27.0.
- **Inferred:** the iPhone app could read the preferred heart-rate zones and send the boundaries to the Watch, either over Watch Connectivity or with the plan over the mirrored session. The Watch would then only bucket the live bpm.
- **Unconfirmed:** whether the system zones iOS 27 returns are the same zones the Series 8 shows, and whether a manual edit on a watchOS 26 Watch reaches iOS 27's preferred configuration. Apple documents the sync for preferred zones in general, not across OS versions. The developer docs and WWDC26 put the setting in "Health Settings". The Support guide puts it under Workout settings on the Watch. No source says the two are the same setting on a watchOS 26 Watch.
- **Inferred:** the iPhone can't read the Watch's own zone setting if it isn't synced. It also can't help when the owner has no date of birth: the configuration would be `nil`.

## 3. HealthKit types for the inputs

### Date of birth

- **Doc:** characteristic types "cannot be used to create and save new HealthKit objects. Instead, users must enter and edit their characteristic data using the Health app. Similarly, you cannot create queries for characteristic types." They are "used only when asking for permission to read data" ([HKCharacteristicType][doc-characteristic]).
- **SDK:** `dateOfBirthComponentsWithError:` (watchOS 3.0+) "Returns the user's date of birth in the Gregorian calendar. Before calling this method, the application should request authorization to access objects with the HKCharacteristicType identified by HKCharacteristicTypeIdentifierDateOfBirth" (`HKHealthStore.h`).
- **Doc:** "If the user has not yet specified a birth date, or if the user has denied your app permission to read the birth date, this method returns `nil`" ([dateOfBirthComponents()][doc-dob]). Temper can't tell "not entered" from "not allowed".
- **Permission:** add it to `read:` only. It can't be shared. It falls under `NSHealthShareUsageDescription`.

### Resting heart rate

- **Doc:** `restingHeartRate` is "an estimation of the user's lowest heart rate during periods of rest". "The system estimates the resting heart rate by analyzing sedentary heart rate samples throughout the day." "Because the resting heart rate estimates become more accurate as the day progresses, the system may delete earlier samples and replace them with better estimates. Apple Watch replaces only the samples written by the watch for the current or previous day" ([restingHeartRate][doc-rhr]).
- **SDK:** count/min, discrete, temporally weighted, watchOS 4.0+ (`HKTypeIdentifiers.h`).
- **Tested:** a `HKSampleQueryDescriptor` for the newest `restingHeartRate` sample (sorted by `endDate`, limit 1) typechecks at watchOS 26.0. So does a request to read date of birth, resting heart rate and heart rate.
- **Permission:** read only, under `NSHealthShareUsageDescription`. Read status is hidden. "If you are not given permission, it simply appears as if there is no data" (Doc, quoted in the [permission research][perm-research]).

### Other candidates

- **`heartRate`** (already read): a statistics query with `.discreteMax` over past workouts gives an observed maximum. On the Watch, "old data is periodically purged from Apple Watch. Use `earliestPermittedSampleDate()` to determine the earliest samples available" ([About the HealthKit framework][doc-about]). The iPhone keeps the full history (Inferred from the same page).
- **`walkingHeartRateAverage`, `vo2Max`, `heartRateRecoveryOneMinute`:** they exist (watchOS 4 and 9) but no Apple source ties them to zones (SDK, Inferred).
- **`biologicalSex`:** some published maximum-rate formulas differ by sex. Apple names only age and resting rate (WWDC, Inferred).

### Reading them on the Watch

- **Doc:** "iPhone, Apple Watch, and visionOS each have their own HealthKit store. … HealthKit automatically syncs data between these devices" ([doc-about]).
- **Inferred:** the Watch writes resting-rate samples itself, so recent ones are in its store. Date of birth is entered on the iPhone and synced. That it is readable on the Watch is likely but not documented for characteristics (Unconfirmed).
- **Measured ([What does a Watch-saved Health workout look like next to the iPhone's own?](https://github.com/igorxciv/temper/issues/108)):** the owner allowed share workouts and read workouts and heart rate on the iPhone. Four seconds later the Watch reported that a request "would not prompt", with no sheet. So one iPhone request covering date of birth and resting heart rate should cover the Watch too (Inferred). Asking for new types shows a sheet only for those types: "If the user has already chosen to grant or prohibit access to all of the types specified, HealthKit calls the completion without prompting the user" ([requestAuthorization][doc-request]).

## 4. What watchOS 27's zone APIs do

All need iOS 27 or watchOS 27 (SDK). Not visionOS or macOS for the live parts.

| API | What it does |
|---|---|
| `HKHealthStore.preferredWorkoutZoneConfiguration(for:) async throws -> HKWorkoutZoneConfiguration?` | The person's manual zones from Health Settings, else the system's, else `nil` (Doc). |
| `HKWorkoutZoneConfiguration(quantityType:zoneBoundaries:) throws` | An app's own zones from a list of boundaries. `source` is `.app`. Zones are "contiguous and nonoverlapping" (Doc). 3 to 9 zones, first from 0, last unbounded, units compatible with the type (WWDC). |
| `HKWorkoutBuilder.setCustomZoneConfiguration(_:for:) async throws` | Overrides the preferred zones for this workout only. Call before `beginCollection`. "Custom configurations apply only to this workout and don't modify the person's preferred zones" (Doc). |
| `HKWorkoutBuilder.zoneConfiguration(for:)` | The custom configuration if set, else the preferred one (Doc). |
| `HKLiveWorkoutBuilderDelegate.workoutBuilder(_:didUpdateWorkoutZone:)` | Called "when the person moves between zones" (Doc). Only on a change (WWDC). Carries `zoneGroup` (the configuration and time in every zone), `currentZoneDuration`, `previousZoneDuration` and `lastSampleProcessedDate` (SDK). |
| `HKWorkout.zoneGroupsByType`, `HKWorkoutActivity.zoneGroupsByType`, `zoneGroup(for:)` | Time in each zone, saved with the workout and each activity (Doc, SDK). |

- **WWDC26:** heart rate and cycling power are the supported types. Cycling power defaults to 6 zones. "Custom zone configurations are only saved within the context of the workout. Your app is responsible for saving, and syncing custom zone configurations, if needed."
- **Inferred, for a later move:** the inputs Temper reads on watchOS 26 become a custom configuration (or Temper uses the preferred one), and the delegate replaces Temper's own bpm-to-zone lookup. A watchOS 27 Watch would also save time in zone with the workout, which Temper's watchOS 26 path can't do. A Series 8 never gets there, so both paths would live side by side behind `#available` (Inferred).

## What the grilling ticket has to choose between

These are the options the facts allow. Picking one is for [How does Temper work out the heart-rate zone the Watch shows?](https://github.com/igorxciv/temper/issues/118).

1. **Compute on the Watch** from date of birth and the newest resting rate, using heart-rate reserve at 60/70/80/90%. This matches the prototype and the reported Apple method. The maximum still needs a rule (an age formula, an observed maximum, or a setting), and so do the missing-data cases.
2. **Read Apple's preferred zones on the iPhone** (iOS 27) and send them to the Watch. These match what Apple's own apps show, manual edits included, if the sync covers the Series 8. Otherwise they fall back to option 1.
3. **A zone setting inside Temper.** No HealthKit dependency, but the owner types numbers.

## What only a device test can settle

1. On the iPhone (iOS 27), call `preferredWorkoutZoneConfiguration(for: .heartRate)`. Compare its boundaries and `source` with the Series 8's Settings › Workout › Heart Rate Zones. Then switch the Watch to Manual, change zone 3, and read again.
2. On the Watch (watchOS 26.5), after the iPhone asks to read date of birth and resting heart rate, check that `dateOfBirthComponents()` returns a value and that the newest `restingHeartRate` sample is recent.
3. Compare zones computed with reserve at 60/70/80/90% (using Apple's displayed maximum and resting values) with the Watch's displayed zones. That confirms or refutes the reported method on the owner's own numbers.

## Sources

[support-zones]: https://support.apple.com/guide/watch/view-heart-rate-zones-apd897dccddf/watchos
[support-zones-9]: https://support.apple.com/en-gb/guide/watch/apd30fa26bb4/9.0/watchos/9.0
[watchos9-notes]: https://support.apple.com/en-za/117792
[newsroom-9]: https://www.apple.com/newsroom/2022/06/watchos-9-delivers-new-ways-to-stay-connected-active-and-healthy/
[wwdc26]: https://developer.apple.com/videos/play/wwdc2026/207/
[doc-preferred]: https://developer.apple.com/documentation/healthkit/hkhealthstore/preferredworkoutzoneconfiguration(for:)
[doc-config]: https://developer.apple.com/documentation/healthkit/hkworkoutzoneconfiguration
[doc-zone]: https://developer.apple.com/documentation/healthkit/hkworkoutzone
[doc-characteristic]: https://developer.apple.com/documentation/healthkit/hkcharacteristictype
[doc-dob]: https://developer.apple.com/documentation/healthkit/hkhealthstore/dateofbirthcomponents()
[doc-rhr]: https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/restingheartrate
[doc-about]: https://developer.apple.com/documentation/healthkit/about-the-healthkit-framework
[doc-request]: https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:)
[perm-research]: https://github.com/igorxciv/temper/blob/research/watch-health-permission/docs/research/watch-health-permission.md
[macrumors]: https://forums.macrumors.com/threads/anyone-getting-weird-automatically-set-heart-rate-zones.2358997/
[9to5mac]: https://9to5mac.com/2024/05/23/heart-rate-zones-apple-watch-iphone
[tomsguide]: https://tomsguide.com/how-to/how-to-use-heart-rate-zones-on-your-apple-watch

- Apple Support and Newsroom: [View Heart Rate Zones on Apple Watch][support-zones] ([watchOS 9 version][support-zones-9]), [About watchOS 9 Updates][watchos9-notes], [watchOS 9 announcement][newsroom-9].
- HealthKit docs: [preferredWorkoutZoneConfiguration(for:)][doc-preferred], [HKWorkoutZoneConfiguration][doc-config], [HKWorkoutZone][doc-zone], [HKCharacteristicType][doc-characteristic], [dateOfBirthComponents()][doc-dob], [restingHeartRate][doc-rhr], [About the HealthKit framework][doc-about], [requestAuthorization][doc-request]. Also read: `HKLiveWorkoutZoneUpdate`, `HKWorkoutBuilder.setCustomZoneConfiguration(_:for:)`, `HKWorkoutBuilder.zoneConfiguration(for:)`, `HKLiveWorkoutBuilderDelegate.workoutBuilder(_:didUpdateWorkoutZone:)`, `HKWorkout.zoneGroupsByType`, `HKHealthStore.earliestPermittedSampleDate()`.
- SDK (Xcode 27.2, watchOS 27.2): `HKHealthStore.h`, `HKTypeIdentifiers.h`, `HKLiveWorkoutBuilder.h`, `HKLiveWorkoutZoneUpdate.h`, `HKMetadata.h`, HealthKit `arm64_32-apple-watchos.swiftinterface`.
- WWDC: [WWDC26 207 Deliver workout insights with HealthKit workout zones][wwdc26].
- Earlier Temper research: [Health permission for the Watch app][perm-research]. Measured results in [What does a Watch-saved Health workout look like next to the iPhone's own?](https://github.com/igorxciv/temper/issues/108).
- Reports: [MacRumors thread][macrumors], [9to5Mac][9to5mac], [Tom's Guide][tomsguide].
