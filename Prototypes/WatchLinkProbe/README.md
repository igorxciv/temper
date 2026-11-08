# PROBE: Watch link

Throwaway. It lives only on the `prototype/watch-link-probe` branch and is never merged. It answers
[Does an iPhone-started mirrored session hold up on iOS 27.2 with the Series 8?](https://github.com/igorxciv/temper/issues/107)

Two apps, both named **Link Probe**:

- **iPhone (`ProbePhone`):** pick a case, tap **Start**. It calls `startWatchApp`, times the completion and the
  mirrored session's arrival, pings the Watch every 5 s, beeps when a Watch tap arrives, and can end the session
  with `stopActivity(with:)` or `end()`. It holds a `.playback` audio session from Start, so it runs while locked
  the way Temper does during a Workout. Its log holds both sides and is in the app's Documents folder.
- **Watch (`ProbeWatch`):** `handle(_:)` makes the session, calls `prepare()`, mirrors only at `.prepared` (the
  workaround for the iOS 26 bug), then starts. Middle page: the session state, a 1:00 countdown drawn from the
  iPhone's date with the Watch's clock, heart rate, the last round trip, and a **Tap** capsule. Swipe right for
  controls (Ask for Health, Stop, Stop mirroring, Mirror again, the Watch log). Swipe left for launch steps and counts.

Each session it saves is an indoor HIIT workout with the metadata `TemperProbe = watch-link-probe`. Delete them
afterwards in Health → Sharing → Apps → Link Probe.

## Build

`Config/Local.xcconfig` must exist in this checkout. Build the **ProbeWatch** scheme with the Watch as the
destination, and the **ProbePhone** scheme with the iPhone. The Watch app installs straight on the Watch; the
iPhone build also embeds it.

## Run on the wrist

Once: open Link Probe on the iPhone and tap **Ask for Health**. On the Watch, open Link Probe, swipe right, and tap
**Ask for Health**. Allow everything on both.

For each run: pick the **Case** on the iPhone, set up the devices as the run says, tap **Start**, and leave the
Watch on the watch face unless the run says otherwise. Don't clear the log between runs.

1. **Awake, Bluetooth.** Watch on the wrist, unlocked, screen on. Start. Tap the Watch capsule 5 times, about 2 s
   apart, and listen for the iPhone's beep each time. End with **stopActivity(with:)** on the iPhone.
2. **Wrist down.** Lower the wrist until the Watch screen is off, wait 10 s, then Start with the other hand. Raise
   the wrist after 15 s. End with **end()** on the iPhone.
3. **Cold launch.** Restart the Watch, unlock it, don't open Link Probe. Start. End with **Stop (Watch)** on the
   Watch's controls page.
4. **Awake, Wi-Fi.** Turn off Bluetooth in the iPhone's Settings app (Control Center isn't enough). Keep both on
   the same Wi-Fi. Start, tap 5 times, end with **stopActivity(with:)**. Keep Bluetooth off for run 5.
5. **Locked 10 min, Wi-Fi.** Start, lock the iPhone, put it a few metres away. After 10 minutes, tap 5 times and
   note whether each beep comes within about 1 s. End with **Stop (Watch)**. Turn Bluetooth back on.
6. **30 min soak, locked, Bluetooth.** Start, lock the iPhone. After 10 minutes, tap 5 times and listen. At about
   15 minutes, turn on Airplane Mode from the lock screen's Control Center for 20 s, then off. Tap 5 times again.
   At 30 minutes, tap 5 times, then end with **stopActivity(with:)**.
7. **Force-quit iPhone.** Start. After 1 minute, force-quit Link Probe on the iPhone. Watch the Watch for a minute:
   state, round trip, a tap. Reopen Link Probe on the iPhone and wait 30 s. End with **Stop (Watch)**.
8. **Watch off.** Power the Watch off. Start, wait 60 s. Power it back on.
9. **Watch off wrist.** Take the Watch off and let it lock. Start, wait 60 s. If a session starts, end with
   **stopActivity(with:)**.

For the clock offset, during any run, hold both screens side by side and see whether the two countdowns agree to
the tenth. The iPhone's **Watch clock ahead** row gives the number.

When done, leave the iPhone unlocked and connected. The log can be copied off the device, or shared from the app.

## What the log answers

- **Wake time:** `startWatchApp called` → `mirrored session #n arrived, X s after startWatchApp`, and the
  completion line, per case. The Watch's own steps (`handle(_:)`, `prepared`, `mirroring started`, `running`) come
  over as `[watch]` lines.
- **The mirroring bug:** `DISCONNECTED` lines, `send failed` lines and the per-minute `link:` counts on both sides.
- **Locked iPhone:** `tap #n arrived ... Watch→iPhone N ms` and `AUDIO NOT RUNNING`, and whether Airplane Mode
  brings `mirrored session #2`.
- **Ending from each side:** the Watch's `saved workout` and `state` lines after `stopActivity` and `end()`, and what
  the Watch logs after the iPhone is force-quit.
- **Clock offset:** `their clock ahead by N ms (±M ms)` in each summary.
