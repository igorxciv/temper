# Timing Probe: PROTOTYPE, throw away

Answers one question: does the researched timing, background, audio and signing approach hold up on a real iPhone? It never ships. Only its verdict moves on.

## Install

1. `cp Config/Local.xcconfig.example Config/Local.xcconfig`, then set your Personal Team ID and a bundle prefix of your own. Git ignores this file. Leave Xcode's Team picker alone, because it writes to the tracked project.
2. Turn on Developer Mode, then open `TimingProbe.xcodeproj` and run on your iPhone with the Debug configuration. Stop in Xcode once the app is installed, and start the runs from the Home Screen, so the debugger can't keep the app alive.
3. Note whether the first launch needed trusting the developer in Settings, and the profile expiry date Xcode shows.

## Runs

Set the options, type the condition into **Note**, press **Start**, and do what the table says. Keep the phone on battery, with no cable and not connected to Xcode, for every run except run 1.

Write down what you hear: every Cue spoken or not, and whether music dipped, paused or recovered.

| # | Preset | Keep-alive | Dip | Conditions | Answers |
|---|---|---|---|---|---|
| 1 | Smoke | Zeros | Off | In front, Silent mode on, no music | Cues play in Silent mode and follow media volume |
| 2 | Smoke | Zeros | Off | Lock right after Start, no music | Locked Cues on a free account |
| 3 | Silent gaps | Zeros | Off | Lock, leave it for the full 1 h 51, no music | **Decides the design**: does it survive long silence? |
| 4 | Standard | Zeros | Off | Lock, Spotify playing | Accuracy and music unaffected |
| 5 | Standard | Zeros | Off | Another app in front, Apple Music playing | Same, backgrounded |
| 6 | Standard | Zeros | A | Lock, Spotify playing | Dip on when locked: does it dip, recover and survive? |
| 7 | Smoke | Zeros | B | Lock, Spotify playing | Does changing options while active dip at all? |
| 8 | Smoke | Zeros | C | Lock, Spotify playing | Only if A failed: separate synthesizer session |
| 9 | Drift | Zeros | Off | Lock, no music, record the speaker on a second device | Drift over 1 h and heard timing |
| 10 | Standard | Zeros | Off | Lock, AirPods or other Bluetooth, then again with Compensate on | Route latency |
| 11 | Standard | Zeros | Off | Lock. Decline a call, then accept one for over 2 min | Cues during and after calls |
| 12 | Standard | Zeros | Off | Lock with Bluetooth, then turn the headphones off mid-run | Route change, Cues from the speaker |
| 13 | Smoke | Zeros | Off | Press Pause, lock for 1 min, return, Resume | Exact time left after Resume |
| 14 | Smoke | Zeros | Off | In front, film the screen in slow motion with sound | Heard delay: the background changes color at each Phase change |

If run 3 dies, repeat it with **Very quiet signal**, then **Engine stopped, session active**. If everything fails, stop there, because that result changes the design.

## Collect the logs

Logs are in the app's Documents folder, visible in the Files app under On My iPhone, and each one can be shared from the app's Logs section. Copy them into `logs/`, which git ignores, then:

```
python3 analyze.py logs/run-*.jsonl
```

A log with no `run_end` means the process died or was still running. To check for suspension or termination, capture a sysdiagnose straight after the run.

Logs hold the device model, iOS version and audio port types. They never hold port names, which can contain a person's name.
