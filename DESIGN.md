---
name: Temper
description: An iOS interval timer in dark ink, where each Phase is a whole color world and setup is the Workout written in those colors.
colors:
  ink-ground: "#11151D"
  ink-raised: "#1B212C"
  ink-separator: "#2E3643"
  warm-white: "#F3F1EA"
  secondary-gray: "#A9ADB5"
  amber: "#E6B566"
  on-amber: "#221702"
  prepare-field: "#0F2433"
  prepare-ring: "#8FCBEF"
  prepare-track: "#274A60"
  prepare-text: "#EFF8FD"
  work-field: "#351C17"
  work-ring: "#FFAE8A"
  work-track: "#59332A"
  work-text: "#FFF5F0"
  rest-field: "#0F2A2B"
  rest-ring: "#86DCCB"
  rest-track: "#254A48"
  rest-text: "#F0FBF8"
  cooldown-field: "#18223F"
  cooldown-ring: "#AFC4FF"
  cooldown-track: "#2F3D66"
  cooldown-text: "#F3F6FF"
  stop-red: "#FF5A5F"
  stop-dark-red: "#40161A"
  on-stop-red: "#1A0506"
typography:
  running-time:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "180pt"
    fontWeight: 600
    fontFeature: "tnum"
  complete-total:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "120pt"
    fontWeight: 600
    fontFeature: "tnum"
  running-count:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "48pt"
    fontWeight: 600
    fontFeature: "tnum"
  hollow-word:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "60pt"
    fontWeight: 700
  running-phase:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "56pt"
    fontWeight: 600
  wheel-digits:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "54pt"
    fontWeight: 600
    fontFeature: "tnum"
  setup-digits:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "52pt"
    fontWeight: 600
    fontFeature: "tnum"
  running-caption:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "28pt"
    fontWeight: 500
    fontFeature: "tnum"
  display:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "34pt"
    fontWeight: 600
  control:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "28pt"
    fontWeight: 700
  headline:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "22pt"
    fontWeight: 700
  title:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "20pt"
    fontWeight: 600
  setup-caption:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "17pt"
    fontWeight: 600
  body:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "17pt"
    fontWeight: 400
  label:
    fontFamily: "SF Pro Rounded, ui-rounded, system-ui"
    fontSize: "15pt"
    fontWeight: 400
rounded:
  band: "18pt"
  capsule: "9999pt"
spacing:
  hairline: "1pt"
  bar-bottom: "6pt"
  bar-top: "8pt"
  stack: "12pt"
  screen-edge: "16pt"
  complete-stack: "20pt"
components:
  button-primary:
    backgroundColor: "{colors.amber}"
    textColor: "{colors.on-amber}"
    typography: "{typography.headline}"
    rounded: "{rounded.capsule}"
    height: "52pt"
  button-close:
    backgroundColor: "{colors.amber}"
    textColor: "{colors.on-amber}"
    typography: "{typography.headline}"
    rounded: "{rounded.capsule}"
    height: "56pt"
  button-running:
    typography: "{typography.control}"
    rounded: "{rounded.capsule}"
    height: "72pt"
  button-done:
    backgroundColor: "{colors.work-ring}"
    textColor: "{colors.work-field}"
    typography: "{typography.control}"
    rounded: "{rounded.capsule}"
    height: "88pt"
  setup-row:
    backgroundColor: "{colors.ink-ground}"
    textColor: "{colors.warm-white}"
    typography: "{typography.setup-digits}"
    padding: "0 16pt"
  value-band:
    backgroundColor: "{colors.ink-separator}"
    rounded: "{rounded.band}"
    height: "68pt"
  list-row:
    backgroundColor: "{colors.ink-raised}"
    textColor: "{colors.warm-white}"
    typography: "{typography.body}"
---

# Design System: Temper

## Overview

**Creative North Star: "Phases in Ink"**

Temper is dark ink with four Phase colors laid on it. Setup is the Workout written in those colors before Start: one row per Phase in the order it runs, a big hollow word in the Phase's ring color at the left, large tabular digits at the right, rows split by hairlines. Starting turns the whole screen into the current Phase's field, with its name at the top, a ring and the time in the middle, and the controls at the foot. When the Workout ends, the complete screen closes that ring in the last Phase's color around the total.

Everything else is native iOS 27 recolored onto the ink: the Liquid Glass tab bar and buttons, navigation, menus, sheets and grouped lists. The app is dark only; there is no light variant. Every color has an Increase Contrast value, listed in the sidecar. SF Rounded is set once at the root and used everywhere.

Scope: this records the iPhone app. The Apple Watch app and the Live Activity draw from the same `InkColors` and `PhaseColors` in `Shared/Ink.swift`; the Watch also uses `StopColors` for its Stop.

**Key Characteristics:**
- Dark ink ground, raised rows one step lighter, hairline separators.
- Amber marks the action to take and nothing else.
- Each Phase has a field, ring, track and text color; a Phase is recognised by its field from across a room.
- Setup labels are hollow words in the Phase's ring color; digits are large, semibold and tabular.
- Liquid Glass for buttons: prominent amber for the primary action, plain glass for the running controls.
- One motion: the complete ring draws closed once, with a success haptic when it closes.

## Colors

A blue-black ink with a warm white, one amber, and four Phase sets that each run from a deep field to a light ring.

### Primary
- **Amber** (amber): the action to take on this screen. The fill of Start, Close, Confirm and Make Plan; the Dip toggle; the selected tab; text buttons that ask for something (Save Workouts to Health, Allow Heart Rate, Make New Plan).
- **On Amber** (on-amber): the label on an amber fill.

### Secondary (the Phase sets)
Each Phase has four colors: a field (the running screen's background and the value sheet's background), a ring (the Phase name on the running screen, the ring's fill, the setup row's hollow word, the Phase's time in the recap and on Describe, the value sheet's title and "Off"), a track (the ring's unfilled stroke and the band behind the wheel's center row), and a text color (the time on the running screen and the wheel's digits).
- **Prepare Blue** (prepare-field, prepare-ring, prepare-track, prepare-text).
- **Work Coral** (work-field, work-ring, work-track, work-text). Work's ring also fills Done, with Work's field as its label, and colors each Round's Work time on Open Rounds' complete screen.
- **Rest Teal** (rest-field, rest-ring, rest-track, rest-text).
- **Cooldown Indigo** (cooldown-field, cooldown-ring, cooldown-track, cooldown-text).

Prepare and Cooldown nearly match under color blindness. That is accepted: they are never adjacent, and the Phase name and Cue tell them apart.

### Tertiary (Watch only)
- **Stop Red** (stop-red, stop-dark-red, on-stop-red): the Watch's Stop, red on a dark red fill, then solid red with dark text when it asks for a second tap. The iPhone app does not use it.

### Neutral
- **Ink Ground** (ink-ground): the background of every screen that isn't a Phase field.
- **Ink Raised** (ink-raised): grouped list rows, and the background of the Preset sheets and of the value sheet for Rounds.
- **Ink Separator** (ink-separator): the 1 pt hairlines between setup rows, the wheel band for Rounds, and the complete ring's track in the rare case no last Phase is known.
- **Warm White** (warm-white): digits, titles, list text.
- **Secondary Gray** (secondary-gray): notes, section headers and footers, captions under digits, the "×" and "·" in the recap, Rounds' hollow word, the value sheet's title for Rounds, the Round count on Open Rounds' complete screen, Preset summaries, and the complete ring's fill when no last Phase is known. The Describe prompt uses it at 0.78 opacity, about 4.5:1 on the raised row.

### Named Rules
**The Amber Means Act Rule.** Amber is the action to take here and nothing else. A label, a count or a decoration is never amber; Rounds' hollow word is secondary gray for this reason.

**The Phase Is the Field Rule.** On the running screen the whole background is the Phase's field, and its name and ring are in the Phase's ring color. A value sheet opened from a Phase row takes that Phase's field, ring, track and text.

**The Contrast Pair Rule.** Every color has an Increase Contrast value in `Shared/Ink.swift`. A new color without one doesn't ship.

## Typography

**Display Font:** SF Pro Rounded (the system font, via `.fontDesign(.rounded)` at the app root and again on the value sheet)
**Body Font:** SF Pro Rounded
**Label/Mono Font:** none distinct; every number uses tabular figures (`.monospacedDigit()`)

**Character:** One rounded face at heavy weights, friendly at a glance and steady when digits change.

### Hierarchy
- **Running time** (600, 180 pt, tabular): the time inside the running ring. Set larger than any phone allows so the ring decides the size; scales down to 0.4, or 0.3 when Done is shown.
- **Complete total** (600, 120 pt, tabular): the total inside the complete ring on both complete screens, scaled to the ring (down to 0.3, or 0.2 in Open Rounds' smaller ring).
- **Running count** (600, 48 pt, tabular): the line under the ring, such as the Round count or the Work time just ended, with a running caption (500, 28 pt) at 0.72 opacity. Kept well under the time so it reads as a note on the ring, never a second clock. "Paused" takes its place at 40 pt semibold in a slot of fixed height, so the ring doesn't move.
- **Hollow word** (700, 60 pt): a setup row's Phase name, outlined; scales down to 0.5 to fit beside the digits.
- **Running phase** (600, 56 pt): the Phase name at the top of the running screen, in its ring color; scales down to 0.6.
- **Wheel digits** (600, 54 pt, tabular): the value sheet's wheels and their colon.
- **Setup digits** (600, 52 pt, tabular): a setup row's value. A setup caption (600, 17 pt, secondary gray) sits under it when the row needs one, such as "then until Done".
- **Display** (600, Large Title): "Workout complete" over both complete screens.
- **Control** (700, Title): Pause, Resume and Done.
- **Headline** (700, Title 2): the labels of Start, Close, Confirm and Make Plan.
- **Title** (600, Title 3): the recap line on the complete screen, and the Round count (secondary gray) on Open Rounds' complete screen, whose Round rows are Title 3 regular. Describe's Plan rows use Title 3 bold for the Phase name and semibold tabular for its time.
- **Body** (400, Body): list rows and text entry.
- **Label** (400, Subheadline): the note above Start, the Health line, Preset summaries.

Fixed sizes are for what is read at a distance (times, Phase names, setup words and digits); they scale down with `minimumScaleFactor`, never up. Text-style roles follow Dynamic Type, capped where they would crowd the iPhone SE: amber buttons and the running controls at XXX Large, the note above Start at Accessibility 2, and the complete screens' title, recap, Round count and Health line at Accessibility 1.

### Named Rules
**The Tabular Rule.** Every number Temper shows uses tabular figures, so a counting time never jitters.

**The Ring Decides Rule.** The running time and the complete total are set above any phone's width and scale down to fit their ring. Size the ring, not the text.

## Layout

Single column on the phone, 16 pt from the screen edges. Layouts must hold on the iPhone SE (375 × 667 pt) at every text size.

Setup fills the space between the navigation bar and the bottom bar with its rows: each row grows to at most 168 pt, so a Workout Type with two rows doesn't stretch them, and the space left over gathers once under the rows. Rows don't scroll; the scroll view is there so a drag stretches them and they spring back. A 1 pt separator-colored hairline runs between rows. In a row, the hollow word sits at the left as an overlay on empty space (its width never widens the row) and the digits at the right, 12 pt apart.

The primary action lives in a bottom bar (`safeAreaBar`), 8 pt above and 6 pt below, with at most one secondary-gray note line 12 pt above it. Start, Close and Make Plan all sit in that same place, in the thumb zone.

The running screen stacks the Phase name at the top, the ring with 10 pt of inset for its stroke, the count line, and the controls at the foot, 8 pt apart, with flexible space taking up the rest. The running and complete screens replace the tab bar entirely.

The complete screen stacks the title, the ring (160 to 300 pt wide, giving way first when space runs short), the recap and the Health line, 20 pt apart. Open Rounds' complete screen has the same order, 12 pt apart: the title, a fixed 180 × 180 pt ring around the total, the Round count, then the list of each Round's Work time with the Health line in its footer. Only that list scrolls.

## Elevation & Depth

Flat. Depth comes from tone only: list rows and sheets are ink raised, one step above the ground. There are no custom shadows. The only lift is native Liquid Glass, drawn by the system: the tab bar, toolbar buttons, the prominent amber buttons, Done, and the plain glass Pause and Stop, grouped in one glass container. Phase fields are a single solid color; no gradients and no tinted glass panes.

### Named Rules
**The Flat Ink Rule.** Nothing casts a shadow of its own. If something needs to stand out, it gets a tone step or Liquid Glass, not a shadow.

## Shapes

Round, everywhere. Buttons are capsules, as Liquid Glass draws them; Stop is a 72 pt glass circle. The rings are full circles with round line caps, starting at 12 o'clock: 20 pt wide on the running screen, 18 pt on the complete screen, 14 pt on Open Rounds' smaller complete ring. The value wheel's center band has 18 pt corners. Separators are straight 1 pt hairlines.

### Named Rules
**The Hollow Word Rule.** A setup row's Phase name is an outlined word: the word in the Phase's ring color, offset 1 pt in twelve directions, with the ground color on top, then one opacity over the whole: 0.62 for a Phase and 0.72 for Rounds, or 0.8 and 0.85 with Increase Contrast. That keeps it a backdrop that still reads at about 4.5:1 (8:1 with Increase Contrast).

## Components

### Buttons
- **Shape:** capsule, full width.
- **Primary (amber):** `.glassProminent` tinted amber, Title 2 bold label in on-amber, 52 pt minimum height: Start, Confirm, Make Plan. Close on the complete screens is the same at 56 pt. One per screen, in the bottom bar.
- **Start's label:** "Start · 08:50" with the Workout's total only when the Workout ends by itself. If any Phase is open or runs past its length until Done, it says only "Start".
- **Close:** the complete screens' action is Close, never Done. Done ends an open Phase.
- **Running controls:** `.glass`, Title bold. Pause/Resume is 72 pt tall and fills the width with an SF Symbol and label; Stop is a 72 pt circle with a stop symbol, and asks before it ends the Workout.
- **Done:** `.glassProminent` tinted Work's ring with Work's field as its label, 88 pt tall, above Pause and Stop in Open Rounds and Stopwatch. Until the engine would take it (Prepare, Rest, Paused, a Stopwatch's Work before its set length) its 88 pt place is held empty, so Pause, Stop and the ring never move; it fades in over 0.25 s when it can be tapped. A light impact haptic on tap.
- **Disabled amber:** Make Plan keeps its place and drops its label to the system's secondary style.

### Lists
- **Style:** native grouped forms and lists on the ink ground (`scrollContentBackground` hidden), rows in ink raised, row text in warm white, headers and footers in secondary gray.
- **Used by:** Settings, Describe, Open Rounds' complete screen, the Preset sheets. A footer, not a row, holds anything that isn't tappable (the About line).

### Inputs / Fields
- **Text field:** a native field in an ink raised row, warm white text, secondary gray prompt. Describe's field grows from 3 to 8 lines.
- **Toggle:** native, tinted amber.

### Value Sheet
A medium-detent sheet in the Phase's field (ink raised for Rounds). The value's name in Headline in the Phase's ring color (secondary gray for Rounds), then the wheels in the Phase's text color over a band in the Phase's track (ink separator for Rounds), 68 pt tall with 18 pt corners. Digits fade to 0.15 opacity and shrink to 0.65 scale away from the center, with a selection haptic as the value changes. "Off" appears in the ring color when a time that can be off reaches zero, always laid out so the wheels don't shift. Amber Confirm at the foot.

### Navigation
- **Tab bar:** the system Liquid Glass tab bar, tinted amber, never minimized: Intervals, Stopwatch, Open Rounds, Describe, Settings, each with an SF Symbol.
- **Setup:** an inline title with the Presets title menu, the picked Preset as subtitle, and a bookmark Presets menu at the trailing edge. Settings uses the system large title.
- **Preset sheets:** native navigation with Cancel and Save, or Edit and Done; the picked Preset is marked with a checkmark.

### Setup Row (signature)
A hollow word at the left in the Phase's ring color (secondary gray for Rounds), setup digits at the right in warm white, an optional setup caption under them. A row that sets a value is a plain button that opens the value sheet; Open Rounds' open Work row only reads.

### Time Ring (signature)
The running screen's ring: a track circle in the Phase's track and a fill in its ring color, 20 pt wide with round caps, the running time inside in the Phase's text color. Both redraw on every display frame.

### Complete Ring (signature)
The running ring, run full. It draws closed once as the complete screen appears, in 0.8 s ease-out, in the last Phase's ring color over its track, and the success haptic plays when the animation completes. With Reduce Motion it is shown closed and the haptic plays at once. If no last Phase is known (rare: the app falls back to the Workout's final Phase), the ring is secondary gray over the separator, never amber. Both complete screens use it around the total. The total sits inside; under it, the recap reads "8 × 0:40 Work · 0:20 Rest" with each Phase in its ring color and the "×" and "·" in secondary gray, and nothing for a Workout without a set number of Rounds. Then one Health line in secondary gray, with a heart symbol in warm white only when the Workout is going to Health ("Saving to Apple Health.", or "Saving to Apple Health, without heart rate." when workouts are allowed but heart rate isn't).

## Do's and Don'ts

### Do:
- **Do** keep amber for the action to take on the screen: one prominent amber capsule in the bottom bar.
- **Do** put a Phase's name in its ring color, on setup, on Describe, in the recap and on the running screen.
- **Do** use tabular figures for every number, and fixed sizes that scale down for anything read at a distance.
- **Do** give every new color an Increase Contrast value in `Shared/Ink.swift`.
- **Do** cap Dynamic Type on bottom-bar buttons and running controls at XXX Large so they can't crowd the iPhone SE.
- **Do** show the complete ring closed, without animation, under Reduce Motion.

### Don't:
- **Don't** color Rounds, a label or a decoration amber.
- **Don't** show a total on Start when the Workout waits for Done.
- **Don't** call the complete screen's action Done; it is Close.
- **Don't** add custom shadows, gradients or tinted glass panes; depth is tone and native Liquid Glass.
- **Don't** add a light variant; the app is dark only.
