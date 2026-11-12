# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

One owner today, who trains in a mix of gym and home sessions. A public App Store release is planned, so the app must make sense to someone who has never seen it: no setup that only the owner understands.

During a Workout the phone sits on a bench, floor or rack, often metres away, and is read at a glance between efforts with sweaty or chalky hands. Before a Workout it's held in one hand, briefly, between other things.

## Product Purpose

Temper runs a Workout: it moves through its Phases, announces each change aloud, and saves the Workout to Apple Health. Success is starting the Workout you mean within seconds and never having to look at the phone mid-set to know where you are.

## Positioning

A Workout is a Plan of Blocks, not a fixed timer type. Intervals, Stopwatch and Open Rounds are built-in Plans; Describe turns a Workout said in words into a Plan on the device with Apple Intelligence, shown as an outline to check before Start. Cues speak every Phase change and duck other audio rather than pausing it.

## Operating Context

- Every Workout starts on the iPhone. Apple Watch can follow it as a remote with heart rate and Zone, and the Live Activity carries it on the Lock Screen and Dynamic Island.
- Open Phases end only when the owner marks Done; nothing ends a Phase by a stray touch.
- Workouts of 1 minute or more save to Apple Health when they end, with heart rate from Apple Watch when present.

## Capabilities and Constraints

- Vocabulary is fixed by `GLOSSARY.md`: Workout, Workout Type, Plan, Block, Preset, Phase (Prepare, Work, Rest, Cooldown), Open, Done, Round, Pause, Cue, Dip, Health workout, Zone.
- iOS 27, SwiftUI, Liquid Glass. No network access and no third-party packages; everything stays on the device.
- Times run 0:00 to 30:00 in 5-second steps; Rounds 1 to 99.
- Timing and Phase logic lives in `Packages/TemperCore`; screens adapt to it rather than the other way round.
- The Watch app and Live Activity follow the iPhone's design in a later round.

## Brand Commitments

- The name Temper.
- The Phase colors: Prepare blue, Work coral, Rest teal, Cooldown indigo, each a background, ring and text set with an Increase Contrast variant (`Shared/Ink.swift`). They are how a Phase is recognised from across a room.

## Evidence on Hand

No marketing assets, testimonials or store listing exist yet. Do not invent them.

## Product Principles

1. Readable from across the room: during a Workout the time and the Phase win over everything else.
2. Start is one tap from the Plan you mean.
3. Nothing ends by accident: Stop asks, Done is never tap-anywhere.
4. Show the Workout that will run, exactly as it will run, before Start.
5. Training never waits on the app: no prompts at Start or at the end.

## Accessibility & Inclusion

VoiceOver labels on every control and value, Increase Contrast variants for every color, and layouts that hold on the iPhone SE (375 × 667 pt) at every text size.
