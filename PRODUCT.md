# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Anyone who trains in a mix of gym and home sessions and wants each change of Phase called out. Temper is a public App Store app, so it must make sense to someone who has never seen it: no account, no sign-in, and no setup before the first Workout.

During a Workout the phone sits on a bench, floor or rack, often metres away, and is read at a glance between efforts with sweaty or chalky hands. Before a Workout it's held in one hand, briefly, between other things.

## Product Purpose

Temper runs a Workout: it moves through its Phases and announces each change aloud. It isn't a workout app, and saves nothing to Apple Health. Success is starting the Workout you mean within seconds and never having to look at the phone mid-set to know where you are.

## Positioning

A Workout is a Plan of Blocks, not a fixed timer type. Intervals, Stopwatch and Open Rounds are built-in Plans; Describe turns a Workout said in words into a Plan on the device with Apple Intelligence, shown as an outline to check before Start. Cues announce every Phase change over other audio, never pausing or lowering it.

## Operating Context

- Every Workout starts on the iPhone. Apple Watch can follow it as a remote with heart rate and Zone, and the Live Activity carries it on the Lock Screen and Dynamic Island.
- No Watch screen waits on the iPhone with nothing to press: while connecting or out of contact, End stops following the Workout on the Watch.
- Open Phases end only when Done is marked; nothing ends a Phase by a stray touch.
- Nothing saves to Apple Health. Apple Watch shows the heart rate from a workout session that saves no workout.

## Capabilities and Constraints

- Vocabulary is fixed by `GLOSSARY.md`: Workout, Workout Type, Plan, Block, Preset, Phase (Prepare, Work, Rest, Cooldown), Open, Done, Round, Pause, Cue, Zone.
- iOS 27, SwiftUI, Liquid Glass. No network access and no third-party packages; everything stays on the device. The one exception is Settings' tip jar, whose StoreKit purchases go through Apple, not to Temper.
- Times run 0:00 to 30:00 in 5-second steps, or 1-second steps if the owner turns them on in Settings; Rounds 1 to 99.
- Timing and Phase logic lives in `Packages/TemperCore`; screens adapt to it rather than the other way round.
- The Watch app and Live Activity follow the iPhone's design in a later round.

## Brand Commitments

- The name Temper.
- The Phase colors: Prepare blue, Work coral, Rest teal, Cooldown indigo, each a background, ring and text set with an Increase Contrast variant (`Shared/Ink.swift`). They are how a Phase is recognised from across a room.

## Evidence on Hand

The App Store listing's text is in `AppStore/`. No other marketing assets and no testimonials exist yet. Do not invent them.

## Product Principles

1. Readable from across the room: during a Workout the time and the Phase win over everything else.
2. Start is one tap from the Plan you mean.
3. Nothing ends by accident: Stop asks, Done is never tap-anywhere.
4. Show the Workout that will run, exactly as it will run, before Start.
5. Training never waits on the app: no prompts at Start or at the end.

## Accessibility & Inclusion

VoiceOver labels on every control and value, Increase Contrast variants for every color, and layouts that hold on the iPhone SE (375 × 667 pt) at every text size.
