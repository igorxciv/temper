---
name: Temper
description: An iOS interval timer whose Plans are written up on a whiteboard and run as flat, dark Phase fields.
colors:
  board-ground: "#F6F7F5"
  board-panel: "#E9EBE8"
  board-row: "#FFFFFF"
  black-marker: "#1E2126"
  secondary-ink: "#5E646C"
  eraser-ghost: "#868C93"
  board-rule: "#D5D8DB"
  on-marker: "#F6F7F5"
  prepare-ink: "#1F6FB2"
  work-ink: "#C63E22"
  rest-ink: "#0E7A6C"
  cooldown-ink: "#4A55B8"
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
typography:
  running-time:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "200pt"
    fontWeight: 600
    fontFeature: "tnum"
  total:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "60pt"
    fontWeight: 700
    fontFeature: "tnum"
  board-time:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "52pt"
    fontWeight: 700
    fontFeature: "tnum"
  board-phase:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "34pt"
    fontWeight: 700
  board-count:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "30pt"
    fontWeight: 700
    fontFeature: "tnum"
  running-phase:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "56pt"
    fontWeight: 600
  display:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "34pt"
    fontWeight: 700
  headline:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "22pt"
    fontWeight: 700
  title:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "20pt"
    fontWeight: 700
  body:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "17pt"
    fontWeight: 400
  label:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "15pt"
    fontWeight: 400
rounded:
  field: "16pt"
  cell: "18pt"
  capsule: "9999pt"
spacing:
  line: "4pt"
  bracket-gap: "10pt"
  cell-gap: "12pt"
  cell-inset: "16pt"
  screen-edge: "20pt"
  section: "28pt"
components:
  button-marker:
    backgroundColor: "{colors.black-marker}"
    textColor: "{colors.on-marker}"
    typography: "{typography.headline}"
    rounded: "{rounded.capsule}"
    height: "56pt"
  button-done:
    backgroundColor: "{colors.work-ring}"
    textColor: "{colors.work-field}"
    rounded: "{rounded.capsule}"
    height: "88pt"
  plan-cell:
    backgroundColor: "{colors.board-ground}"
    textColor: "{colors.black-marker}"
    rounded: "{rounded.cell}"
    padding: "16pt"
  board-line:
    backgroundColor: "{colors.board-ground}"
    typography: "{typography.board-phase}"
    height: "64pt"
  text-field:
    backgroundColor: "{colors.board-panel}"
    textColor: "{colors.black-marker}"
    rounded: "{rounded.field}"
    padding: "12pt 14pt"
  value-band:
    backgroundColor: "{colors.board-panel}"
    rounded: "{rounded.cell}"
  list-row:
    backgroundColor: "{colors.board-row}"
    textColor: "{colors.black-marker}"
---

# Design System: Temper

## Overview

**Creative North Star: "The Coach's Whiteboard"**

Every iPhone screen but the running one is a gloss whiteboard. A Plan is written on it exactly as it will run: each Phase's name in its own marker ink at the left, its time large in one tabular column at the right, and the lines that repeat held in a hand-drawn bracket under their count. When the Workout ends, the same board comes back with every line ticked off and the total written under a marker line.

Starting a Workout flips the board to a flat dark field in the Phase's color, where the time gets nearly all of the screen so it reads from across a room. The two halves share the Phase hues and SF Rounded, and nothing else: the board is light, quiet and written by hand; the field is dark, flat and given wholly to one number.

Marker strokes (round-nib, slightly wobbly, round caps) draw structure: brackets, ticks, underlines and cell frames. They never draw letters. Everything that reads is SF Rounded. The rest is native iOS 27: Liquid Glass bar buttons, navigation, menus, sheets and grouped lists, recolored onto the board.

Scope: this records the iPhone app. The Apple Watch app and the Live Activity keep their earlier dark ink (`InkColors` in `Shared/Ink.swift`) until a later round. They are not part of the board system, and nothing here should be applied to them yet.

**Key Characteristics:**
- Light whiteboard ground; black marker for structure, names and Start.
- Four Phase marker inks, used as text and strokes, never as fills on the board.
- Times big, bold, tabular, right-aligned in one column.
- Hand-drawn marker strokes for brackets, ticks, underlines and frames; never for words.
- The running Workout is a flat dark Phase field: no gradients, no tinted glass, no ring.
- Every color has an Increase Contrast variant.

## Colors

A near-white board, a near-black marker, and four saturated marker inks, deepened from the brand Phase colors until each clears 4.5:1 on the board.

### Primary
- **Black Marker** (black-marker): names, counts, brackets, underlines, headings, and the fill of every primary capsule (Start, Close, Confirm, Make Plan, Allow). Also the app-wide tint.

### Secondary (the Phase marker inks)
- **Prepare Blue Ink** (prepare-ink): the Prepare line's name, time and tick.
- **Work Coral Ink** (work-ink): the Work line, each Round's time on Open Rounds' complete screen, and Describe's error text.
- **Rest Teal Ink** (rest-ink): the Rest line, and the Apple Health "On" state in Settings.
- **Cooldown Indigo Ink** (cooldown-ink): the Cooldown line.

### Tertiary (the running Phase fields)
Each Phase has a field (the whole screen's background), a ring (the Phase name, the progress fill, and Done's fill for Work), a track (the unfilled progress bar), and a text color (the time and the count). These are the brand Phase colors from PRODUCT.md and how a Phase is recognised from across a room. The running screen forces the dark color scheme.

### Neutral
- **Gloss Board** (board-ground): the background of every board screen and sheet.
- **Board Panel** (board-panel): a field set into the board: the Describe text field, the band behind the value wheel's center row.
- **Lifted Row** (board-row): grouped list rows in Settings and the Preset sheets.
- **Secondary Ink** (secondary-ink): notes, footnotes, captions, a cell's total, the chevron, Preset subtitles.
- **Eraser Ghost** (eraser-ghost): a line that won't run (an Off Phase) and the "Off" under the wheel. It clears 3:1 and is only used at 34 pt or larger, or as the cell's body-bold text.
- **Board Rule** (board-rule): the hand-drawn frame round each Plan cell.
- **On Marker** (on-marker): text on a black marker capsule.

### Named Rules
**The Ink Is the Phase Rule.** On the board a Phase's name and time are always in that Phase's ink, and a value sheet's title and wheels take the ink of the line that opened it. Black marker is for structure (counts, brackets, headings), not for Phase content.

**The Ghost Means Off Rule.** A line that won't run is wiped toward eraser ghost, its time drops to 34 pt semibold, and it's left off the complete board. Ghost is never used for live content.

**The Contrast Pair Rule.** Every color has an Increase Contrast value (in `BoardInk` and `PhaseColors`; listed in the sidecar). A new color without one doesn't ship.

## Typography

**Display Font:** SF Pro Rounded (the system font with `.fontDesign(.rounded)` set at the app root, plus rounded inline navigation titles set through UIKit appearance)
**Body Font:** SF Pro Rounded
**Label/Mono Font:** none distinct; numbers use tabular figures (`.monospacedDigit()`)

**Character:** One friendly, heavy rounded face throughout, so the board reads as a coach's hand-printed lettering without imitating handwriting.

### Hierarchy
- **Running time** (600, 200 pt, scaled down to the width): the time on the running field. The width alone decides its size.
- **Total** (700, 60 pt, tabular): the total on both complete screens, the biggest number on the board.
- **Running phase** (600, 56 pt): the Phase name on the running field, in its ring color. The count under the time is 64 pt semibold with a 32 pt medium caption at 72% opacity.
- **Board time** (700, 52 pt, tabular): a line's time. An Off line's time drops to 34 pt semibold.
- **Board phase** (700, 34 pt): a line's Phase name, in its ink. Line minimum height 64 pt.
- **Board count** (700, 30 pt, tabular): a Rounds Block's count, "× 8" with a thin space, or "× ∞" for Rounds until Stop.
- **Display** (700, Large Title): screen titles: "Plans", "Settings", "Workout complete".
- **Headline** (700, Title 2): section headings, Start and other capsule labels, "Describe a Workout", "Total", "Round 3".
- **Title** (700, Title 3): a Plan cell's name. The cell's lines are Body bold; its count and total are Subheadline bold, tabular.
- **Body** (400, Body): text entry and list rows.
- **Label** (400, Subheadline / Footnote): notes under the board, Health notes, Preset subtitles, captions.

The board's sizes are fixed so a line reads at arm's length on every iPhone; they scale down (`minimumScaleFactor`) rather than up. Text-style roles follow Dynamic Type. Capsule buttons cap at XXX Large so they can't crowd the board on an iPhone SE.

### Named Rules
**The One Column Rule.** Every time on a board is right-aligned in one column, in tabular figures, at the same size as its siblings. Names sit left, times sit right, nothing between them but space.

**The Bold Board Rule.** Board content is bold (700). Regular weight is for notes and system text only.

## Layout

Single column on a phone. Board screens use a 20 pt screen edge; Plans uses 16 pt so its cells get more width. Sections stack 28 pt apart; cells sit 12 pt apart; board lines 4 pt apart with a 64 pt minimum height; a Rounds Block adds 6 pt above and below.

Plans is a grid of whole Plan cells: Intervals across the full width, the other Workout Types two to a row at equal height, Presets two to a row with an odd last cell spanning the row, then Described and the underlined "Describe a Workout" link. At accessibility text sizes it falls to one cell per row, and a cell's line wraps its time under its name rather than truncating.

The primary action lives in a bottom bar (`safeAreaBar`) with the notes just above it, so it stays in the thumb zone while the board scrolls. Layouts must hold on the iPhone SE (375 × 667 pt) at every text size.

On the running field, the Phase name sits at the top, the time and a 10 pt capsule progress bar in the middle, and the controls at the bottom (72 pt Pause and Stop, an 88 pt Done above them when open).

## Elevation & Depth

The board is flat. Depth comes from tone only: the panel is a step darker than the board, list rows a step lighter. There are no drop shadows. The only lift is native Liquid Glass, on the bar buttons and the capsule buttons, as the system draws it. The running field is flat too: one solid color per Phase, no gradients and no tinted glass panes; its Pause and Stop are plain `.glass`.

### Named Rules
**The Flat Board Rule.** Nothing on the board casts a shadow or sits on a card fill. A group is boxed with a marker stroke, not raised.

## Shapes

Corners are generous and soft: capsules for every button and the progress bar; 18 pt for a Plan cell's frame and the value wheel's band; 16 pt continuous for the text field.

The signature shape is the marker stroke (3.5 pt, round cap, round join), drawn as gently bowed curves rather than straight lines:
- **Bracket:** opens right, 14 pt arms, the spine bowing outward a hair. It holds a Rounds Block's lines (2 pt and 6 pt wide at cell size).
- **Tick:** a short downstroke and a long flick up, in the line's ink, 22 × 18 pt.
- **Underline:** sags in the middle and lifts at the end; under "Describe a Workout" and above a complete screen's total.
- **Cell frame:** a closed rounded box with slightly bowed sides, 2.5 pt in board rule.

### Named Rules
**The Strokes Not Letters Rule.** Marker strokes draw brackets, ticks, underlines and frames. Words stay in SF Rounded.

## Components

### Buttons
- **Shape:** capsule, full width, 56 pt minimum height, Title 2 bold label.
- **Primary (black marker):** `.glassProminent` tinted black marker with on-marker text: Start (with the Workout's length, "Start · 8:50"), Close, Confirm, Make Plan, Allow in Settings. One per screen, in the bottom bar.
- **Secondary:** `.glass` tinted black marker (Make New Plan once a Plan exists).
- **Running controls:** `.glass` Pause (72 pt tall, flexible width) and a 72 pt square Stop with an SF Symbol. Done is `.glassProminent` tinted the Work ring with Work-field text, 88 pt tall; disabled, it dims in place.
- **Toolbar:** native glass circles with SF Symbols (Settings gear, Presets bookmark, Back).

### Cards / Containers (Plan cell)
- **Corner Style:** 18 pt, drawn as a marker cell frame in board rule.
- **Background:** the board itself; no fill.
- **Shadow Strategy:** none (Flat Board Rule).
- **Internal Padding:** 16 pt; name (Title 3 bold) and optional subtitle (Footnote, secondary ink), then a mini board, then the total (or "Until Stop") in Subheadline bold secondary ink at the foot.

### Inputs / Fields
- **Text field:** board panel fill, 16 pt continuous corners, 12 × 14 pt padding, black marker text and caret, secondary ink prompt.
- **Value sheet:** a medium-detent sheet on the board ground; a 54 pt semibold tabular digit wheel in the line's ink over an 18 pt panel band; "Off" in ghost when the draft is zero; black marker Confirm.
- **Lists:** native grouped lists on the board ground, rows in lifted row white, headers and labels in black marker, footers in secondary ink.

### Navigation
Native iOS 27 navigation. "Plans" and "Settings" set their large titles themselves so they're rounded (Large Title bold, black marker). A Plan's screen has an inline rounded title with a title menu and a Presets menu at the trailing edge. Board links are underlined in marker with a secondary-ink chevron.

### Plan Board (signature)
Lines top to bottom: Phase name left (34 pt bold, its ink), time right (52 pt bold tabular, its ink), an optional 17 pt semibold caption under the time in secondary ink. A Rounds Block puts its count in a 64 pt column at the left, then the marker bracket, then its lines 10 pt in. An Off line is ghosted; an open line reads "until Done". With editing on, each line and count is a plain button that opens its value. One note line and "Tap a line to change it." sit above Start in secondary ink.

### Complete Board (signature)
"Workout complete", then the board as it ran with each line ticked in its ink, the ticks drawn top to bottom (0.3 s ease-out, 0.18 s apart, after a 0.3 s beat), then a marker underline drawn after the last tick, then "Total" with the 60 pt total, then the Health note. Reduce Motion shows the ticks at once. Open Rounds lists "Round N" in black marker with its Work time in work ink, ticked in work ink, the stagger capped at ten Rounds.

### Running Field (signature)
Flat Phase field, Phase name in ring color, the time in the Phase's text color as wide as the screen allows, a capsule progress bar (ring on track), the Rounds count below. Dark color scheme throughout.

## Do's and Don'ts

### Do:
- **Do** write a Phase's name and time in its marker ink on the board, and a Rounds count and bracket in black marker.
- **Do** put every time in the right-hand tabular column at the fixed board size (52 pt for a line, 60 pt for a total).
- **Do** keep one black marker capsule per screen, in the bottom bar.
- **Do** draw structure with the 3.5 pt round-cap marker stroke as gently bowed curves.
- **Do** give every new color an Increase Contrast variant and check it against the board (4.5:1, or 3:1 for text 34 pt and up).
- **Do** let Reduce Motion show drawn strokes in their finished state.

### Don't:
- **Don't** fill board containers or give them shadows; box them with a marker stroke.
- **Don't** draw letters or words as marker strokes.
- **Don't** use a Phase ink as a fill on the board; fills in Phase color belong to the running field.
- **Don't** add gradients, tinted glass panes or an activity ring to the running field.
- **Don't** use eraser ghost for anything that will run.
- **Don't** apply the board system to the Watch app or the Live Activity yet.
