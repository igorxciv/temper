---
version: 2
slug: "temper"
primary_target: "Temper"
related_targets: []
---

## Scope

The iPhone app's screens: the three setup tabs (Intervals, Stopwatch, Open Rounds), Describe, Settings, the value sheet, the Preset sheets, the running screen and the complete screens. Visitor mode: Operate. The Watch app and Live Activity keep their look; they already share this ink.

## Audience and task

One owner now, the App Store later; gym and home. Before a Workout: one hand, seconds, pick or adjust a Workout Type or Preset and Start. During: phone metres away, read at a glance. After: confirm it ran and whether it went to Health.

## Constraints

Phase colors are a brand commitment (`Shared/Ink.swift`). Dark only; the owner chose the dark ink over a light board redesign, which was built, merged and reverted. Native tab bar, navigation, sheets, menus and Liquid Glass buttons. Fixed sizes for times and Phase names, read at distance; iPhone SE at every text size; Increase Contrast variants for every color.

## Direction contract

THESIS: Each Phase is a whole color world, and setup is the Workout written in those colors, one row per Phase in the order it runs, before Start.

OWN-WORLD: Dark ink ground #11151D, raised rows #1B212C, separators #2E3643, warm white text #F3F1EA, secondary #A9ADB5. Amber #E6B566 means act here and nothing else: Start, Confirm, Close, toggles, the tab tint. Each Phase has a background, ring, track and text color (Prepare blue, Work coral, Rest teal, Cooldown indigo), each with an Increase Contrast set. SF Rounded throughout. Setup labels are big hollow words in their Phase's ring color, about 4.5:1, scaled to fit beside the digits; Rounds' word is neutral, not amber. Digits are large, semibold, tabular. The running screen is the Phase's whole field with a ring and the time. Complete closes that ring.

STORY: Temper opens on the last Workout Type's tab. The owner sees every Phase in order, Stopwatch's Work marked "then until Done" and Open Rounds' Work "Open, until Done", taps a row to change it, and Starts with one tap from the thumb zone. Mid-set the Phase field reads from across the room. At the end the ring closes in the last Phase's color around the total, with what the Rounds ran and whether the Workout goes to Health.

FIRST VIEWPORT: The Intervals tab. Inline title with the Presets title menu and a bookmark Presets menu at the trailing edge. Five rows, Prepare, Rounds, Work, Rest, Cooldown, each a hollow word at the left and 52 pt digits at the right, split by hairlines. A single note line in secondary above "Start · 08:50", an amber glass capsule over the tab bar. Signature interaction: on the complete screen the ring draws closed once in the last Phase's color, with a success haptic; Reduce Motion shows it closed.

FORM: The incumbent dark ink, refined against the 27/40 critique: complete screen, Stopwatch and Open Rounds rows, Presets reach, Describe palette, label truncation and contrast, wheel selection band, About footer, Close for Done. seed: none (roll waived; the owner asked to "return vibe of the previous one but adjust it based on your suggestions and best practices")

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md recorded from the shipped code.

## Unresolved

- Skipping Prepare or Rest mid-Workout: not decided.
- Whether Describe stays a tab or becomes a way into setup.
