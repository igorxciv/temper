# PROBE: Watch Health save

Throwaway. It lives only on the `prototype/watch-health-probe` branch and is never merged. It answers
[What does a Watch-saved Health workout look like next to the iPhone's own?](https://github.com/igorxciv/temper/issues/108)
It started as a copy of the Link Probe from
[Does an iPhone-started mirrored session hold up on iOS 27.2 with the Series 8?](https://github.com/igorxciv/temper/issues/107).

Two apps, both named **Health Probe**, with a new bundle ID so the permission runs start from nothing:

- **iPhone (`ProbePhone`):** pick a run and tap **Start**. It calls `startWatchApp`, runs a stand-in Workout of
  Work 20 s and Rest 10 s with a beep at each Phase, and sends the plan, Phases, Pause, Resume and Stop with its record
  over the mirrored session. In runs A and B it also saves its own workout the way Temper does, with sync version 1.
  **List probe workouts** prints every probe workout Health shows: source, device, sync version, events,
  activities, and the heart-rate samples linked to it. Its log holds both sides and is in the app's Documents folder.
- **Watch (`ProbeWatch`):** `handle(_:)` logs the workout permission and makes the session whatever it says. It
  prepares, mirrors at `.prepared`, waits for the plan, then starts at the iPhone's Start date. Activities come live
  from `beginNewActivity`, with each Phase after the first dated 1.5 s early, or at Stop from the iPhone's record with
  `addWorkoutActivity`. The plan decides which. It saves with the plan's sync identifier and version 1,000,000. The
  first page is the session. Swipe right for controls: Ask for Health, Status, **Ask in handle(_:)**, List probe
  workouts, Stop (Watch), and the log.

Every workout it saves carries the metadata `TemperProbe`. Delete them afterwards in Health › Sharing › Apps ›
Health Probe.

## Build

`Config/Local.xcconfig` must exist in this checkout. Build **ProbeWatch** for the Watch and **ProbePhone** for the
iPhone, or install the built apps with `xcrun devicectl device install app`.

## Already answered at launch

The Watch app logs `typesToCollect` for the three activity types, and its status, when it launches. See the first
progress comment on the ticket.

## Run on the wrist

Do the runs in order. The permission runs depend on nothing having been asked yet. Wear the Watch for all of them.
Don't clear the log. Ending a run with **Stop (Watch saves)** on the iPhone is enough unless a step says otherwise.
If a run never shows a mirrored session within 30 s, end it with **Stop (Watch)** on the Watch's controls page and
go on.

**Permission (P1 to P5)**

1. **P1, nothing allowed anywhere.** Open Health Probe on the iPhone. Don't tap Ask for Health. Pick **Plain
   session** and tap **Start**. Watch the Watch for 40 s and note anything that appears. Tap **Stop (Watch saves)**.
2. **P2, a sheet from the background launch.** On the Watch, open Health Probe, swipe right and turn on **Ask in
   handle(_:)**. Press the Crown to go back to the watch face. On the iPhone, **Start** a Plain session. Look at the
   Watch. Does a Health sheet appear? **Don't answer it.** After 60 s, tap **Stop** on the iPhone. Open Health
   Probe on the Watch, which logs its status. Then answer the sheet with **Don't Allow**, or turn everything off.
   If no sheet is showing, tap **Ask for Health** on the Watch and do the same. Turn **Ask in handle(_:)** off.
   On the iPhone, tap **Status** but not Ask for Health.
3. **P3, workouts denied on the Watch.** On the iPhone, **Start** a Plain session. After 30 s, **Stop**.
4. **P4, allowed on the iPhone.** On the iPhone, tap **Ask for Health** and turn everything on. If no sheet appears,
   turn everything on in Settings › Privacy & Security › Health › Health Probe. Open Health Probe on the Watch, which
   logs its status. Note which entries Settings › Health on the iPhone lists for Health Probe, and which the Watch's
   Settings › Health › Apps lists.
5. **P5, heart rate with no read permission.** Get the Watch app to "share workouts allowed, read Heart Rate off":
   tap **Ask for Health** on the Watch, or use the Watch's Health settings if no sheet appears. If the Watch has no
   separate setting, turn Heart Rate reading off for Health Probe on the iPhone. **Start** a Plain session, wait
   60 s, **Stop**. Then turn Heart Rate reading back on for both.

**Workouts (R1 to R4)**

6. **R1, run A.** Pick **A: iPhone v1 first, live activities**. **Start**. About 10 s in, **Pause**; 10 s later,
   **Resume**. At about 1:30, **Stop**. The iPhone lists probe workouts 4 s after the session ends.
7. **R2, run B.** Pick **B: Watch v1,000,000 first, record activities**. Same as R1.
8. **R3, after Health syncs.** Wait 5 minutes. Tap **List probe workouts** on the iPhone and on the Watch's controls
   page. Then look at the A and B workouts in the Health app (Browse › Activity › Workouts) and in Fitness. Note how
   many there are, the source each shows, whether heart rate shows, and how the Rounds, Pause and activities appear.
   Screenshots help.
9. **R4, rings.** Note the Move and Exercise numbers in Fitness. Pick **Open Rounds rings, record activities**.
   **Start**, then do real sets for about 10 minutes with the Watch on. **Stop**. After a couple of minutes, note
   Move and Exercise again, and what Fitness shows for that workout. The iPhone-only save from the Open Rounds device
   check gave no Move credit to note.

When done, leave the iPhone unlocked and connected. Both logs are copied off the devices with
`xcrun devicectl device copy from`.

## What the log answers

- **Cross-source replacement (R1, R2, R3):** the `probe workouts visible here` blocks on each device. Run A has
  `iPhone v1` then `(Watch)` v1000000 with one sync identifier. Run B has the reverse. One workout per identifier
  means replacement crosses sources. Two means it doesn't. Each block also shows the source, and whether the
  heart-rate samples are still linked.
- **Default collection:** the `typesToCollect` lines at launch, and `session made; collecting …` per run.
- **Activities:** run A's `beginNewActivity … dated` and `activity began: … recorded start minus asked` lines say
  whether a past date holds. Run B's `added N activities from the record`, and both runs' activity lists, show what
  ended up in Health.
- **Permission:** `status (…)` lines on both sides, `workouts … in handle(_:)`, `request inside handle(_:) returned
  after …`, `session failed`, `first heart-rate update`, `heart-rate updates N, M with a value`, and the
  `finishWorkout` lines. The `source […]` in each listing names the bundle the Watch's workout and samples carry.
