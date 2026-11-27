---
status: accepted
---

# The Watch leaves another app's workout running

Apple Watch runs one workout session at a time, across all apps, and the one that starts second ends the other ([#153](https://github.com/igorxciv/temper/issues/153)). So until now, Start in Temper ended an Apple Workout the owner had started. The owner finds that too much. A workout they started keeps running, even though Temper's Watch screen then can't run beside it. No API lets two apps' sessions run at once, or puts Temper's above Apple Workout's, so leaving it running is the only option.

No API reports another app's session either. When the iPhone opens the Watch at Start, a Watch with no session of its own counts the heart-rate readings Health got in the last minute (`OtherWorkout`). Under any workout session Apple Watch measures every few seconds, and outside one every few minutes. Five or more readings means a workout is running: the Watch starts no session, and says "Another Workout Is Running" until it goes to the background. The Workout runs on, on the iPhone, as it does with no Watch.

## Consequences

- With another app's workout running, the Watch shows no Phase, heart rate or Zones, and doesn't tap the wrist. The iPhone's Live Activity still shows in the Watch's Smart Stack.
- The check is a guess from the pace of readings, and has not been run on a device. If Apple Workout saves its readings in batches, the Watch misses it and ends it as before. A workout ended less than a minute before Start can still look like it's running, so that Workout runs without the Watch. The device check should start Temper with Apple Workout running, and again just after ending it.
- Starting Apple Workout during a Temper Workout still ends Temper's session, as before. The Watch can't stop that.
- The check reads heart rate, which Temper already asks for. Without that grant it counts nothing, and the Watch starts its session as before.
