# App Store submission

The decisions behind the first submission (#182), and a draft of the notes for App Review. The owner files these in App Store Connect.

## Decisions

- **China mainland is left out of Pricing and Availability.** `AudioAdapter` uses `CXCallObserver` to hold Cues back during a call, and App Review in mainland China rejects any CallKit use. Dropping CallKit would mean treating every interruption as a possible call, which would also hold Cues back after Siri or an alarm. New apps in mainland China also need an ICP filing.
- **HealthKit: submit as is, with a review note.** Temper saves no workouts (ADR 0002). The note explains that the Watch's workout session exists only for live heart rate. If App Review insists on a save option, that reopens ADR 0002.
- **Background audio.** The audio session is active only while a Workout runs: Pause, Stop and the end of the Workout release it. The silence between Cues keeps the engine running, so Cues play on time while the iPhone is locked.
- **Live Activity.** A timed Phase goes stale 30 s after its end. An open Phase or a Stopwatch's Work goes stale 10 minutes after it's shown, and Temper shows it again every 5 minutes while it runs. A Paused Phase never goes stale: Pause releases the audio session, so a locked Temper is suspended and couldn't renew it, and Resume has to stay. A stale Live Activity dims and drops its button.
- **Apple Watch.** "Connecting to iPhone" and "iPhone not connected" each offer End, so a reviewer whose iPhone app has gone isn't left waiting 10 minutes. During a dropout End takes Stop's place on the secondary page, a swipe right from the time. The issue also names a "Running on iPhone" screen, but the Watch has none: its waiting screen reads "Connecting to iPhone" and "Your Workout has started on the iPhone".
- **EU trader status: recommended non-trader**, for the owner to confirm. Temper is free, with no ads, purchases or subscriptions, and it is published by an individual outside any business. A trader's address, phone and email would show publicly on EU product pages.
- **Release** is manual.

## Review notes (draft)

Temper is an interval timer with no account or sign-in, and it works fully offline. To run a short Workout: open Temper, choose Intervals, set Rounds to 2, Work to 0:10 and Rest to 0:05, and tap Start. Each Phase change is announced with a gong (or the chime or beep picked in Settings) or spoken words, over any other audio. To hear a Cue with the iPhone locked, start the Workout, press the side button, and wait for the next Phase change. Force-quitting Temper ends the Workout and stops the Cues. Apple Watch is optional: with Temper installed on a paired Watch and Health access allowed in Settings, Start opens the Watch, which shows the Workout and the heart rate. The Watch runs a workout session only to read live heart rate, and Temper saves no workouts to Health. Describe, which turns a spoken Workout into a Plan, needs Apple Intelligence. On a device without it, Describe says why it's unavailable, and the rest of the app works the same. A screen recording of the Cues playing with the iPhone locked is attached.
