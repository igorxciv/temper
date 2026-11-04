# What can a Temper Watch app on a Series 8 do for quick, mostly no-look control?

Research for ticket #72, on map #70. Sources were read on 2026-11-03. API facts were checked against Apple's documentation and the watchOS 27.2 and iOS 27.2 SDKs in Xcode 27.2.

Nothing here has been run on a Watch. The open questions are listed in [What only a Series 8 can settle](#what-only-a-series-8-can-settle).

**How claims are marked**

- **No mark, with a citation:** stated by Apple's developer documentation, the Human Interface Guidelines (HIG), an SDK interface, a WWDC session or an Apple Support page.
- **[Secondary]:** a press or how-to site, used only where I found no Apple page.
- **[Inferred]:** my reasoning from the cited facts. Apple does not state it.
- **[Unconfirmed]:** I looked and found no primary source.

## Summary

- **Staying on screen needs a workout session on the Watch.** An app with an active `HKWorkoutSession` keeps running when the wrist drops, comes back on every wrist raise, and updates about once per second in Always On. Without a session, the app stays frontmost for at most an hour (two minutes by default), and its dimmed screen updates about once a minute. Who owns that session is ticket #73's question.
- **A tap on the dimmed Always On screen hits the button.** Apple says controls stay interactive in Always On, and a tap runs the action and wakes the app. Series 8 has Always On. Tapping without looking works with the wrist down, as long as the button sits where the finger lands.
- **The Digital Crown's rotation is the only physical input an app gets.** Presses of the Digital Crown and the side button belong to the system. The Action button is on Ultra models only.
- **Series 8 has no Double Tap and no wrist flick.** Both need Series 9 or later, Ultra 2 or later, or SE 3. Adding `.handGestureShortcut(.primaryAction)` costs one line, works in the Watch app and on the iPhone Live Activity in the Smart Stack, and does nothing on a Series 8.
- **The existing Live Activity already shows on the Watch, Pause/Resume button included.** The intent runs in the iPhone app. Apple publishes no latency, and whether the tap works while the iPhone is locked is undocumented.
- **No Apple guidance covers accidental touches from sleeves.** The HIG's sizes: 44×44 pt default, 28×28 pt minimum, and full-width buttons for primary actions. Water Lock blocks all touches, which rules it out as a guard.

## 1. Staying frontmost and updating during a Workout

### With a workout session

From [Running workout sessions][running]:

- "Your app continues to run throughout the entire workout session, even when the user lowers their wrist or interacts with a different app. When the user raises their wrist, your app reappears."
- On the watch face, a small icon shows a session is running. A tap on it goes back to the app.
- The app can alert with audio or haptics in the background.
- It needs the Workout processing background mode, plus Audio if it plays sound or haptics during the session. Excessive background CPU can get it suspended.

From [Designing your app for the Always On state][aod]:

- "Apps running a background session, such as a workout session or background audio session, remain onscreen as long as the session is active." They keep updating their UI at a reduced rate.
- Always On "isn't available on Apple Watch SE or Apple Watch Series 4 and earlier." Apple lists Series 8 with an Always-On Retina display ([Series 8 tech specs][s8specs]).

From [Updating watchOS apps with timelines][timelines]:

- In Always On, "apps running a background session may not need to use a `TimelineView`… the system only refreshes the user interface about once per second."
- Apps with background runtime get the `.seconds` cadence (up to one update per second).
- `Text` with the `.timer` date style updates in Always On without the app's help ([aod][aod]). Temper's Live Activity already uses `Text(timerInterval:pauseTime:countsDown:)`. The Watch app can show its counts the same way [Inferred].

**Starting the Watch side from the iPhone.** `HKHealthStore.startWatchApp(toHandle:)` (iOS 10+) "will launch the WatchKit app corresponding to the calling iOS application on the currently active Apple Watch." The Watch app then receives the `HKWorkoutConfiguration` and can start a session (iOS 27.2 SDK, `HKHealthStore.h`). WWDC23's [Build a multi-device workout app][wwdc23] uses this call so that an iPhone tap starts the Watch session, which then mirrors to the iPhone. HealthKit keeps the two sessions' states in sync, and either side can send data to the other with `sendToRemoteWorkoutSession(data:)`, up to 100 KB per 10 seconds (watchOS 27.2 SDK, `HKWorkoutSession.h`).

Apple tells a companion that starts the Workout on iPhone that, once the Watch app opens, it "should automatically start a workout session for the workout in progress" ([running][running]). Whether Temper's session lives on the Watch, the iPhone or both, and what that means for Health, belongs to ticket #73. This ticket only finds that a session on the Watch is what keeps the Watch app on screen.

### Without a workout session

From [aod][aod]:

- When the wrist drops, the app becomes inactive. The system keeps showing it "as long as your app remains the frontmost app (usually two minutes)", then suspends it.
- The user sets this under Return to Clock, per app, up to "a maximum of 1 hour" ([aod][aod]; [display settings][display]).
- Pressing the Digital Crown or covering the screen sends the app to the background at once.
- An inactive frontmost app updates "generally at the `.minutes` frequency", with short `.seconds` bursts if it asks for them ([timelines][timelines]).

An hour-long gym session would outlast this, and a dimmed Rest countdown that ticks once a minute is useless [Inferred].

### Extended runtime sessions

`WKExtendedRuntimeSession` offers Self care (frontmost, 10 minutes), Mindfulness (frontmost, 1 hour), Physical therapy (background, 1 hour) and Smart alarm ([Using extended runtime sessions][extended]). Apple says to pick the type "based on the app's intended use—not based on the features that the session provides." For strenuous activity, it points to `HKWorkoutSession` instead. A gym Workout is a workout, and the 1-hour cap is too short, so this route doesn't fit [Inferred].

### Wrist down and Always On

- "Any controls in the user interface remain interactive. Users can tap buttons, toggle switches, or select items from a list. When the user interacts with a control, the system runs the associated action and transitions your app back to the active state" ([aod][aod]). So the first tap on a dimmed screen is not spent waking it.
- The user can turn off Always On for the whole device or per app ([aod][aod]). It's also off in Low Power Mode ([display settings][display]).
- Wake on Wrist Raise and Wake on Crown Rotation are both user settings ([display settings][display]).

## 2. Digital Crown and buttons

- **Rotation:** yes. SwiftUI's `digitalCrownRotation` modifiers report the value through a binding, with an `onChange` that receives a `DigitalCrownEvent` (`offset`, `velocity`) and an `onIdle` that fires when the Crown settles. Optional detents and haptics are available (watchOS 27.2 SDK, SwiftUI interface; [digitalCrownRotation][crownapi]). Apple's example makes the view `.focusable()` first.
- **Crown press:** no. "Apps don't respond to presses on the Digital Crown because watchOS reserves these interactions for system-provided functionality like revealing the Home Screen" ([HIG: Digital Crown][hig-crown]). A press goes to the watch face or Home Screen, a double-click opens the App Switcher, and press-and-hold starts Siri ([buttons and gestures][gestures-support]).
- **Side button:** no. It opens Control Center, starts Emergency SOS or Apple Pay, or powers the watch off ([buttons and gestures][gestures-support]). I found no API that lets an app capture it, in the docs or in the watchOS 27.2 SDK [Unconfirmed as a negative, checked by search].
- **Action button:** Ultra only, and the user assigns it to a workout start or similar. Its subsequent presses can mark segments, and pressing it with the side button pauses ([HIG: Action button][hig-action]). Series 8 has none.

**A firm Crown turn as the backup.** It works as an input [Inferred from the API]. A detented binding with a large stride and low sensitivity can demand a deliberate turn, and haptic detents confirm it. Three things are unknown: whether the first turn on a dimmed screen reaches the app or only wakes it, how many false turns lifting produces (a wrist bent back against the Crown), and whether Wake on Crown Rotation being off changes delivery.

## 3. Double Tap, wrist flick and other hand gestures

**Models.** Double Tap and wrist flick need Apple Watch Series 9 or later, Ultra 2 or later, or SE 3 ([If tap gestures aren't working][tap-models]). The HIG says Double Tap can "perform a primary action on Apple Watch Series 9 and later and Apple Watch Ultra 2 and later" ([HIG: Gestures][hig-gestures]). **Series 8 has neither.**

**What apps get.** The only hand-gesture API is `HandGestureShortcut`, and it has one value, `.primaryAction` (watchOS 11+; watchOS 27.2 SDK SwiftUI interface; [handGestureShortcut][hgs]). There is no API for wrist flick. The system uses it to "dismiss anything and return to the watch face" ([gestures for notifications][flick]). Double Tap also doesn't work while the wrist is down and the display is inactive, in Low Power Mode, or when the watch is locked ([Use double tap][doubletap-guide]).

**Is `handGestureShortcut` nearly free?** Yes [Inferred from the docs below]:

- One modifier on the button: `.handGestureShortcut(.primaryAction)`. It is available on iOS 18+ as well as watchOS 11+, so it compiles in TemperWidgets.
- "You can even add it to widgets and live activities that appear in the Smart Stack, including remote live activities from iOS" ([Enabling double tap][enable-dt]). The existing `PauseResumeButton` can carry it.
- Limits: one primary action per scene, and the control must be on screen. Avoid putting it in a view with a list, scroll view or vertical tabs, because Double Tap scrolls those ([enable-dt][enable-dt]; [HIG: Gestures][hig-gestures]).

On a Series 8 it does nothing, so the owner can't test it. Its cost is a line per button and a check that the scene isn't scrolling [Inferred].

## 4. The existing Live Activity on the Watch

**It already shows.** "In iOS 18 and watchOS 11, your iOS Live Activity will appear in the Smart Stack on Apple Watch automatically" ([WWDC24: Bring your Live Activity to Apple Watch][wwdc24]). With `.supplementalActivityFamilies([.small])`, the Watch gets the `.small` layout instead of the compact views. That is what `WorkoutLiveActivity` declares and what `SmallPhaseView` draws. The card is 165×72.5 pt on a 41 mm watch and 184×80.5 pt on a 45 mm one ([HIG: Live Activities][hig-la]).

**The Pause/Resume button works from the Watch.** The HIG says a custom watchOS layout "can show more information and add interactive functionality like a button or toggle." It names "stopwatch or timer controls" as a good use ([HIG: Live Activities][hig-la]). Buttons are switched off only in CarPlay ([Displaying live data][la-doc]).

**Where the tap runs.** For a `LiveActivityIntent`, "the system performs the app intent in the app's process" ([Adding interactivity][interactivity]). Temper has no Watch app, so the tap runs in the iPhone app [Inferred]. Apple documents this relay for iPhone widgets on a Mac ("the system sends the interaction to iPhone… This process may take extra time") but says nothing like it for the Watch [Inferred by analogy].

**How quickly.** Apple publishes no latency figure [Unconfirmed]. What it documents:

- Updates sync to the Watch automatically and are budgeted. An update over budget "may not immediately appear when someone's wrist is down", but the card shows the latest state when the wrist rises ([wwdc24][wwdc24]).
- With poor connectivity, Start, End and alert updates are sent first. A "last connected" message marks stale content ([wwdc24][wwdc24]).
- Temper updates the card only at a Phase change, Pause, Resume and the end, and the system counts the time itself. This stays well inside the budget [Inferred].
- A tap therefore crosses Watch to iPhone, runs `pause()`, then the new state crosses back. The Cue, spoken on the iPhone, isn't delayed by the return trip [Inferred]. The runner reads the clock when the intent reaches it (the comment on `PauseResumeButton` in `TemperWidgets/WorkoutLiveActivity.swift`), so the relay delay adds directly to the measured time. For a hand-ended Work, that is the time Work takes.

**Locked iPhone.** "On a locked device, buttons and toggles are inactive and the system doesn't perform actions unless a person authenticates and unlocks their device" ([Adding interactivity][interactivity]). Apple doesn't say whether this applies to a Watch tap that runs on a locked iPhone in a pocket [Unconfirmed]. This is the biggest open question for the Live Activity route.

**Tapping the card.** Without a Watch app, a tap on the card (outside the button) opens a full-screen view with a button to open the app on the iPhone. With a Watch app and the `Supports Launch for Live Activity Attribute Types` Info.plist key, the tap opens the Watch app ([HIG: Live Activities][hig-la]; [Launching your app from a Live Activity][launch]).

**When the card appears.** It shows at the top of the Smart Stack when the Live Activity begins ([HIG: Live Activities][hig-la]). An update with an alert launches the Smart Stack if no app is in use ([launch][launch]). An "Auto-Launch Live Activities" setting on the Watch controls whether the card takes over the face [Secondary: [MacRumors][macrumors]]. The Smart Stack is a stack, so the owner may have to scroll to reach Temper's card [Inferred].

## 5. Large tap targets and tap-anywhere

**System conventions:**

- Default control size 44×44 pt, minimum 28×28 pt on watchOS. Spacing matters as much as size: about 12 pt around bezeled elements and 24 pt around unbezeled ones ([HIG: Accessibility][hig-a11y]).
- "Prefer buttons that span the width of the screen for primary actions in your app. Full-width buttons look better and are easier for people to tap" ([HIG: Buttons][hig-buttons]).
- For workouts: "Provide workout controls that are easy to find and tap." "Use large font sizes, high-contrast colors" when the session involves movement. Show the data people care about between wrist raises, such as elapsed or remaining time, "and offer relevant controls like lap or interval markers" ([HIG: Workouts][hig-workouts]).
- "Avoid using a familiar gesture like tap or swipe for an app-specific action" ([HIG: Gestures][hig-gestures]). A whole-screen button is still a tap on a control, so tap-anywhere fits if the whole screen is visibly one button [Inferred].

**Limits found:**

- **Covering the screen dismisses the app.** Covering the display silences alerts ([buttons and gestures][gestures-support]). For an app without a session, covering it sends the app to the background at once ([aod][aod]). Whether a flat-palm slap on a tap-anywhere screen reads as a tap or a cover is undocumented [Unconfirmed].
- **Edge swipes belong to the system** ([HIG: Gestures][hig-gestures]). A full-screen button still gets the system's edge and toolbar areas around it [Inferred].
- **Water Lock blocks every touch.** Third-party apps can call `WKInterfaceDevice.enableWaterLock()` only "when the app is running in the foreground during an active workout or location session," and can't unlock it ([enableWaterLock][waterlock-api]). The user unlocks it by pressing and holding the Digital Crown, and tap gestures don't work while it's on ([Water Lock][waterlock]). It guards against sleeves but kills the tap, so it isn't a fix [Inferred].
- **Sleeves and sweat.** No Apple page covers a sleeve or wet skin brushing the screen [Unconfirmed]. The defenses an app controls are where the button sits, its size, and making the quick action safe to repeat [Inferred].

**Large target versus tap-anywhere.** The docs don't decide this. The map leaves it to the prototype. The facts here: the HIG supports a full-width primary button, Always On keeps both kinds of control live, and a single big button leaves the screen's top half for the time and Phase name [Inferred].

## What only a Series 8 can settle

1. **Dimmed-screen tap.** With a workout session running and the wrist down, does one tap on the Always On screen fire the quick action? Does it fire on the first tap after the screen has gone fully dark, or does that tap only wake it?
2. **Live Activity tap with a locked iPhone.** Does Pause/Resume from the Smart Stack work while the iPhone is locked in a pocket? Measure the time from tap to the iPhone's state change, and from the tap to the card's update, over several tries.
3. **Watch app round trip.** Time from a tap in a Watch app (by WatchConnectivity `sendMessage`, or a mirrored session's data channel) to `pause()` on the iPhone. Compare it with the Live Activity's time from step 2.
4. **Crown as backup.** Does a firm turn on a dimmed screen reach the app? How often does lifting turn it by accident? What stride and sensitivity separate deliberate turns from accidental ones?
5. **Tap-anywhere false touches.** How often do sleeves, a towel or wet skin fire a full-screen button over a set? Does a flat palm read as a tap or as a cover?
6. **Smart Stack reach.** With the Live Activity running, how many swipes away is Temper's card on wrist raise, and does it stay on top through a Rest?

Today a Pause takes its time from when the intent runs on the iPhone. Run items 2 and 3 before deciding whether the Watch should send the tap's own time along with it.

## Sources

[running]: https://developer.apple.com/documentation/healthkit/running-workout-sessions
[aod]: https://developer.apple.com/documentation/watchos-apps/designing-your-app-for-the-always-on-state
[timelines]: https://developer.apple.com/documentation/watchos-apps/updating-watchos-apps-with-timelines
[extended]: https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions
[wwdc23]: https://developer.apple.com/videos/play/wwdc2023/10023/
[wwdc24]: https://developer.apple.com/videos/play/wwdc2024/10068/
[crownapi]: https://developer.apple.com/documentation/swiftui/view/digitalcrownrotation(detent:from:through:by:sensitivity:iscontinuous:ishapticfeedbackenabled:onchange:onidle:)
[hig-crown]: https://developer.apple.com/design/human-interface-guidelines/digital-crown
[hig-action]: https://developer.apple.com/design/human-interface-guidelines/action-button
[hig-gestures]: https://developer.apple.com/design/human-interface-guidelines/gestures
[hig-la]: https://developer.apple.com/design/human-interface-guidelines/live-activities
[hig-a11y]: https://developer.apple.com/design/human-interface-guidelines/accessibility
[hig-buttons]: https://developer.apple.com/design/human-interface-guidelines/buttons
[hig-workouts]: https://developer.apple.com/design/human-interface-guidelines/workouts
[hgs]: https://developer.apple.com/documentation/swiftui/view/handgestureshortcut(_:isenabled:)
[enable-dt]: https://developer.apple.com/documentation/watchos-apps/enabling-double-tap
[la-doc]: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
[launch]: https://developer.apple.com/documentation/activitykit/launching-your-app-from-a-live-activity
[interactivity]: https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities
[waterlock-api]: https://developer.apple.com/documentation/watchkit/wkinterfacedevice/enablewaterlock()
[tap-models]: https://support.apple.com/108413
[doubletap-guide]: https://support.apple.com/guide/watch/apdabb7b275c
[flick]: https://support.apple.com/guide/watch/apd8bcbaa778/watchos
[gestures-support]: https://support.apple.com/105063
[waterlock]: https://support.apple.com/108352
[display]: https://support.apple.com/guide/watch/adjust-the-display-settings-apd127ec93ac/watchos
[s8specs]: https://support.apple.com/111848
[macrumors]: https://www.macrumors.com/how-to/apple-watch-live-activities-fix/

- Apple developer documentation: [Running workout sessions][running], [Designing your app for the Always On state][aod], [Updating watchOS apps with timelines][timelines], [Using extended runtime sessions][extended], [Enabling the double-tap gesture][enable-dt], [`handGestureShortcut(_:isEnabled:)`][hgs], [`digitalCrownRotation`][crownapi], [`enableWaterLock()`][waterlock-api], [Displaying live data with Live Activities][la-doc], [Launching your app from a Live Activity][launch], [Adding interactivity to widgets and Live Activities][interactivity].
- WWDC: [WWDC23 10023, Build a multi-device workout app][wwdc23]; [WWDC24 10068, Bring your Live Activity to Apple Watch][wwdc24].
- HIG: [Digital Crown][hig-crown], [Action button][hig-action], [Gestures][hig-gestures], [Live Activities][hig-la], [Accessibility][hig-a11y], [Buttons][hig-buttons], [Workouts][hig-workouts].
- Apple Support: [If tap gestures aren't working][tap-models], [Use double tap][doubletap-guide], [Gestures for notifications and alerts][flick], [Use buttons and gestures][gestures-support], [Water Lock][waterlock], [Display settings][display], [Series 8 tech specs][s8specs].
- SDK: watchOS 27.2 SwiftUI and AppIntents interfaces (`HandGestureShortcut`, `digitalCrownRotation`, `DigitalCrownEvent`); iOS 27.2 `HealthKit/HKHealthStore.h` (`startWatchApp(toHandle:)`).
- Secondary: [MacRumors on Auto-Launch Live Activities][macrumors].
