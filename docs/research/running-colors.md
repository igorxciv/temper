# Running screen colors and type

**Question.** What colors and type should the running screen use so that it stays legible at a distance and is calm and encouraging rather than irritating?

**Answer.** Use Direction A: a dark neutral background, one lighter Phase-colored ring, and a near-white countdown in SF Pro Rounded Semibold with fixed-width digits. Provide light and increased-contrast variants. Compare it with Direction B on a device in the gym before deciding, because no source or calculation here can measure how either one feels.

Scope and method: Apple's HIG pages were read as text from their documentation data. All contrast and color-blindness figures come from the script in the appendix. Nothing here was tested on a phone or in a gym. Harmony was not consulted, since the question marked it as optional and Radix and Material were enough.

## 1. Dark with one accent, or a saturated flood

### What the sources state

| Source | Statement | Scope |
| --- | --- | --- |
| [HIG Color, watchOS](https://developer.apple.com/design/human-interface-guidelines/color) | "Avoid using full-screen background color in views that are likely to remain onscreen for long periods of time, such as in a workout or audio-playing app." | watchOS only. There is no iOS equivalent. |
| [HIG Color, watchOS](https://developer.apple.com/design/human-interface-guidelines/color) | Background color can "establish a sense of place", and should be used "when you have something to communicate, rather than as a solely visual flourish". | watchOS only. This partly supports Phase tinting. |
| [HIG Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts) | "When a session requires movement, use large font sizes, high-contrast colors, and arrange text so that the most important information is easy to read." | iOS and watchOS. It does not say dark or light. |
| [HIG Color, Liquid Glass](https://developer.apple.com/design/human-interface-guidelines/color) | "too much color can be overwhelming and make control labels more difficult to read". | Mainly toolbars and tab bars over colorful backgrounds. |
| [HIG Color, visionOS](https://developer.apple.com/design/human-interface-guidelines/color) | "Prefer using color in bold text and large areas. Color in lightweight text or small areas can make them harder to see and understand." | visionOS only, but it cuts against a thin colored ring. |
| [HIG Color, visionOS](https://developer.apple.com/design/human-interface-guidelines/color) | "avoid displaying a bright object on a very dark or black background, especially if the object flashes or moves". | Fully immersive visionOS, with eyes adapted to darkness. It is a caution against assuming black is always restful. |
| [Material for Wear OS, M2.5](https://developer.android.com/design/ui/wear/guides/m2-5/styles/color) | "Saturated colors also produce optical vibrations against a dark background, which can cause eye strain. Instead, use desaturated colors as a more legible alternative." It recommends "lighter tones (200-50), rather than saturated tones (900-500)". | Wear OS. It gives no citation or measurement. |
| [Material dark theme codelab](https://codelabs.developers.google.com/codelabs/design-material-darktheme) | "More saturated colors tend to visually "vibrate" against darker backgrounds, making them harder to read." It also says pure `#FFFFFF` text "can harm legibility" on dark backgrounds, and gives `#121212` as the typical base. | Design guidance, not a study. |
| [Material Android color docs](https://github.com/material-components/material-components-android/blob/master/docs/theming/Color.md) | Dark baseline: surface neutral 6, on-surface neutral 90, primary tone 80, primary container tone 30. | Sets the tonal pattern both directions follow. |
| [Radix, understanding the scale](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale) | Steps 1 and 2 are for app backgrounds, steps 9 and 10 for solid backgrounds, step 12 for high-contrast text. | Palette structure only. It is a useful cross-check. |

### What the research says about strain, red and irritation

- **"Vibration" has weak evidence.** Google's claim is the strongest direct statement, and neither Google page cites data. Apple's Color, Dark Mode, Typography, Accessibility, Materials and Workouts pages never mention vibration, eye strain or fatigue. A text search of all six found no such wording.
- **Chromostereopsis is real, but it is a different setup.** [Thompson, May and Stone (1993)](https://www-users.york.ac.uk/~pt2/ThompsonMayStone1993.pdf) say saturated reds and blues on a dark screen appear at different depths, and that this can be "either an eye-catching bonus to a display or a distinct irritation to the viewer". The irritation is an aside, not a measurement. The effect needs red and blue together.
- **Saturated blue fared worse than red in the most relevant study.** [BIOJ 2026](https://bioj-online.com/articles/10.22599/bioj.515) had 30 young adults read colored text on black on an iPad at 50 cm. Blue gave the largest accommodative lag, and red did not differ significantly from black on white. The authors warn against "short-wavelength, saturated text". The study used uncalibrated color and five-minute tasks, so it does not support the idea that red is the worst color to read.
- **Saturation and brightness raise arousal.** [Wilms and Oberfeld (2018)](https://doi.org/10.1007/s00426-017-0880-8), with 62 participants viewing a large LED panel for 30 seconds per color: "saturated and bright colors were associated with higher arousal", arousal "increased from blue and green to red", and skin conductance was stronger for saturated and bright colors. This is the best support for the owner's reaction.
- **The same study complicates the story.** Valence ratings were also "the highest for saturated and bright colors". Desaturating may calm the screen without making it more pleasant.
- **Discomfort research doesn't cover flat fields.** [Penacchio et al. (2021)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8720932/) link discomfort to chromaticity differences between neighboring pixels in abstract art. A uniform flood has none, so this neither supports nor refutes the complaint.
- **Dark and light mode results are small and mixed.** [Sengsoon and Intaruk (2025)](https://pmc.ncbi.nlm.nih.gov/articles/PMC12027292/) found no significant fatigue difference on tablets, and their conclusion leans further than their data. [Pathari et al. (2024)](https://personales.upv.es/thinkmind/ACHI/ACHI_2024/achi_2024_3_150_20069.html) report less self-reported fatigue with dark mode in bright ambient light and no significant effect in dim light. I found no meta-analysis I could confirm.
- **WCAG doesn't address static color.** [Three Flashes](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes-or-below-threshold.html) covers flashing only. The flood's Work red has R/(R+G+B) = 0.830, which meets its 0.8 definition of saturated red, so full-screen red must never pulse. A single Phase change is well under three flashes per second.

### Where "encouraging" has no evidence

No source tested whether a workout timer's colors feel encouraging. The general field is shaky. [Elliot (2015)](https://www.frontiersin.org/articles/10.3389/fpsyg.2015.00368/full) calls color psychology "at a nascent stage of development", says "much of the research remains underpowered", and urges "patience and prudence". The claim that processing the word red impairs intellectual performance failed [four replication attempts by Gnambs et al.](https://pure.fh-ooe.at/en/publications/processing-the-word-red-and-intellectual-performance-four-replica/). [Apple notes](https://developer.apple.com/design/human-interface-guidelines/color) that red means danger in some cultures and is positive in others. Claims like "teal is calming" or "coral motivates" should be treated as design opinion, including where they appear to explain this proposal.

### My inference from the above

These points are my judgment, not statements from any source:

1. A dark background with one accent is better supported than a flood, though only moderately. Apple's closest rule is scoped to watchOS, and Google's is uncited. They agree in direction, and the arousal data fits.
2. The flood's main cost is probably at handling distance. A phone face of about 72 x 150 mm fills about 10 x 21 degrees at 40 cm, close to Wilms and Oberfeld's 18 x 18 degree field. At 3 m it fills about 1.4 x 2.9 degrees. So the flood is loudest when setting up and resting nearby, and at 3 m its advantage over a ring may be smaller than expected. Testing should cover both distances.
3. Showing one accent at a time removes the red-beside-blue setup behind chromostereopsis, and lighter tones follow Google's advice.
4. Dark also has a real cost. It gives up the flood's large luminous area, which is the easiest thing to spot across a room. Direction A keeps more chroma in its ring for that reason.

## 2. Proposal

Each Phase uses one ring color, used for the ring and Phase name. The countdown and Round number use the text color. Pause and Stop stay monochrome glass with no Phase tint, since the [HIG](https://developer.apple.com/design/human-interface-guidelines/color) warns against adding color to multiple controls. The ring is content, so it has no glass, in line with the `liquid-glass` skill.

The ring should be a single flat 22 pt stroke over a dim track that depletes as time runs out. Apple says to [differentiate other ring-like elements from Activity rings](https://developer.apple.com/design/human-interface-guidelines/activity-rings), so use no concentric rings or gradient. Apple's [progress guidance](https://developer.apple.com/design/human-interface-guidelines/progress-indicators) says to "keep progress indicators moving", which a continuous sweep does.

### Direction A: dark neutral with a Phase-colored ring

| Phase | Background | Ring and Phase name | Track | Time text | Time : bg | Name : bg | Ring : bg | Ring : track |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Prepare | `#101114` | `#F5D06F` | `#2C2E33` | `#F5F5F7` | 17.34 | 12.71 | 12.71 | 9.14 |
| Work | `#101114` | `#FF8A66` | `#2C2E33` | `#F5F5F7` | 17.34 | 8.16 | 8.16 | 5.87 |
| Rest | `#101114` | `#66DCCA` | `#2C2E33` | `#F5F5F7` | 17.34 | 11.38 | 11.38 | 8.19 |
| Cooldown | `#101114` | `#9DB4FF` | `#2C2E33` | `#F5F5F7` | 17.34 | 9.36 | 9.36 | 6.73 |

### Direction B: deep Phase tint with a lighter tonal ring

| Phase | Background | Ring and Phase name | Track | Time text | Time : bg | Name : bg | Ring : bg | Ring : track |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Prepare | `#2B2210` | `#F8DE9C` | `#4D3F22` | `#FBF7EF` | 14.68 | 11.89 | 11.89 | 7.77 |
| Work | `#33191A` | `#FFAD96` | `#573230` | `#FFF6F3` | 15.24 | 9.01 | 9.01 | 6.13 |
| Rest | `#0F2A28` | `#8FE3D4` | `#25483F` | `#F1FBF8` | 14.39 | 10.21 | 10.21 | 6.79 |
| Cooldown | `#182340` | `#BCCBFF` | `#303F66` | `#F4F6FF` | 14.39 | 9.70 | 9.70 | 6.47 |

### Thresholds

All values, in all sets including the light and increased-contrast ones in the appendix, pass these checks:

- Time text at least 7:1, which is [Apple's target for custom colors](https://developer.apple.com/design/human-interface-guidelines/dark-mode).
- Phase name at least 4.5:1, Apple's stated minimum. [WCAG 1.4.3](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) would allow 3:1 at this size.
- Ring at least 3:1 against both background and track, per [WCAG 1.4.11](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html). That the ring counts as a required graphic is my reading, since the digits give the same information.

The track against the background is 1.39 to 2.16 in the dark sets, which is below 3:1 on purpose. The track only shows the part already used. The ring-to-track boundary carries the information. If the owner counts the empty track as essential, brighten it.

For comparison, the flood's Work fill `#C71217` has CIELAB chroma 80, against 57 for Direction A's Work ring and 36 for B's. Its black-on-Prepare and white-on-Work text contrast were fine (13.89 and 5.95), so the flood's problem was not WCAG contrast.

### Work and Rest under color blindness

Matrices: [Machado, Oliveira and Fernandes (2009)](https://www.inf.ufrgs.br/~oliveira/pubs_files/CVD_Simulation/CVD_Simulation.html), severity 1.0 protanopia and deuteranopia, applied in linear RGB. Differences are CIEDE2000 (ΔE00).

| Ring pair, Work and Rest | Normal | Deuteranopia | Protanopia |
| --- | --- | --- | --- |
| A dark `#FF8A66` / `#66DCCA` | 53.0 | 27.5 | 21.2 |
| B dark `#FFAD96` / `#8FE3D4` | 43.5 | 20.9 | 13.6 |
| B background `#33191A` / `#0F2A28` | 29.7 | 8.6 | 4.2 |
| Old flood `#C71217` / `#33D17A` | 78.0 | 23.9 | 43.3 |

Simulated Work and Rest rings in Direction A become `#C5B464` and `#C0C3CC` under deuteranopia, and `#A89B63` and `#D3D1C9` under protanopia. Olive against neutral gray stays distinguishable.

Reading these results:

- **Direction A separates Work and Rest better than B.** Under protanopia, B's backgrounds nearly merge at ΔE00 4.2, so its tint adds little.
- **The flood beats A under protanopia,** because its huge lightness gap survives. Its fill also covered the whole screen.
- **Prepare and Work are the weak pair:** ΔE00 9.5 under deuteranopia and 15.9 under protanopia in Direction A, and 7.4 and 11.8 in B. The Phase name and Prepare's position before the first Round carry that distinction, as Apple's ["more than color alone"](https://developer.apple.com/design/human-interface-guidelines/accessibility) rule asks.
- **There is no standard pass mark.** ΔE00 is not calibrated for thin strokes seen at a distance. Blue-yellow differences are also generally harder to see in small targets, which is from my background knowledge and was not checked against a source. The ring stroke is about 4.2 arcminutes at 3 m. If Work and Rest look alike at distance, widen the stroke first.

Sensitivity: the Machado paper implies linear RGB without stating it outright, according to the [R colorspace documentation](https://colorspace.R-Forge.R-project.org/reference/simulate_cvd.html). Applying the matrices to gamma-encoded values instead gives A 30.4 and 22.1, B 22.1 and 13.8, so the ranking holds.

### Light appearance

Yes, supply one. Apple says to ["make sure all your app's colors work well in light, dark, and increased contrast contexts"](https://developer.apple.com/design/human-interface-guidelines/color), to supply an increased-contrast option for each custom variant, and to provide both even for a single-appearance app "to support Liquid Glass adaptivity". [Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) allows a dark-only interface "in rare cases", and its example is immersive media, which this is not. The `liquid-glass` skill also requires testing all of these.

Locking the running screen with `preferredColorScheme(.dark)` would be defensible but is a deliberate departure, and Pathari et al.'s bright-room result is too thin to justify it alone. Build light first, look at it in the gym, and decide then.

| Light, Phase | A bg | A ring | A name | A track | A time | Time : bg | Name : bg | Ring : bg | Ring : track |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Prepare | `#F7F6F3` | `#9A6F00` | `#7A5900` | `#DEDCD6` | `#16171A` | 16.59 | 5.97 | 4.18 | 3.29 |
| Work | `#F7F6F3` | `#AD3A1B` | `#A63716` | `#DEDCD6` | `#16171A` | 16.59 | 6.11 | 5.72 | 4.51 |
| Rest | `#F7F6F3` | `#007A6C` | `#006B5F` | `#DEDCD6` | `#16171A` | 16.59 | 5.95 | 4.86 | 3.83 |
| Cooldown | `#F7F6F3` | `#3D5BC4` | `#3552B5` | `#DEDCD6` | `#16171A` | 16.59 | 6.42 | 5.56 | 4.39 |

The B light set and all increased-contrast sets are in the appendix output. Apple warns that [custom backgrounds can hide the system's base and elevated distinction](https://developer.apple.com/design/human-interface-guidelines/dark-mode). That matters little on a full-screen view with no layered surfaces. I could not read the exact system background values from Apple's text, so `#101114` was not compared with `systemBackground`. Swapping it in is reasonable if it reads the same.

### Why Direction A

Direction A follows the closest Apple rule, with no full-screen color during a workout, and it gives Work and Rest more separation than Direction B under both simulated deficiencies. It keeps one background across Phases, so a Phase change alters the ring and name but not the whole screen. Direction B's advantage is unmeasured but plausible: it may feel warmer and give a stronger sense of place, which Apple's watchOS guidance values. Its tint is weak evidence at distance, since backgrounds at L* 12 to 15 emit little light. So B is worth trying, and the owner's reaction on a device should outweigh this reasoning.

## 3. Type

### What Apple says

- ["In general, avoid light font weights."](https://developer.apple.com/design/human-interface-guidelines/typography) Prefer "Regular, Medium, Semibold, or Bold" and avoid "Ultralight, Thin, and Light font weights, which can be difficult to see, especially when text is small."
- Apple adds that with a custom thin font you should go larger than the recommended sizes. It gives no distance figures, and huge digits are not directly covered.
- Rounded variants exist "to coordinate text with the appearance of soft or rounded UI elements, or to provide an alternative typographic voice". Apple does not say rounded digits are more or less legible.
- System fonts use dynamic optical sizes, so SwiftUI's system font needs no manual Display cut.
- [`monospacedDigit()`](https://developer.apple.com/documentation/swiftui/font/monospaceddigit()) "uses fixed-width digits". Apple's docs do not discuss timers specifically. Without it, measured Semibold digit widths range from 0.467 to 0.639 em, so the countdown would shift each second.

### What I measured

From the appendix's AppKit script, with fixed-width digits, as fractions of the em. These are Mac measurements of the same family and should be rechecked on a device.

| Weight | Pro stem : height | Rounded stem : height | Pro `0:45` width | Rounded `0:45` width |
| --- | --- | --- | --- | --- |
| Thin | 0.052 | 0.054 | 1.976 | 1.988 |
| Regular | 0.118 | 0.118 | 2.028 | 2.067 |
| Medium | 0.148 | 0.148 | 2.085 | 2.122 |
| Semibold | 0.170 | 0.170 | 2.125 | 2.164 |
| Bold | 0.200 | 0.199 | 2.182 | 2.219 |
| Heavy | 0.245 | 0.242 | 2.263 | 2.299 |

SF Pro and Rounded have nearly identical stems and differ in width by under 2 percent. So measured metrics don't favor either design. The choice is about voice.

### Recommendation

**SF Pro Rounded, Semibold, fixed-width digits.** Rounded matches the circle, and it's the softer voice the owner asked for, which is an aesthetic judgment and not an evidence-based one. Semibold is inside Apple's preferred range. Heavy, used in the flood prototype, is outside it, and its closed shapes may be what made the digits feel loud. If Rounded feels childish, change `design: .rounded` to `.default`. The size barely changes.

Stem ratio evidence is secondary and conflicting. A traffic-sign study seen in search results, which I did not open, puts the optimum for light on dark near 1:5.6. [A university course deck](https://faculty.ksu.edu.sa/sites/default/files/4%20-%20Chapter%204%20-%20Vision%20-%20part%202%20%28AMS%20May01_24%29.pdf) gives the older rule of thumb of 1:8 to 1:10, because light strokes appear to spread. Semibold is 1:5.9 and Regular is 1:8.5. Try Medium if Semibold looks clotted at distance.

```swift
// Time left. Fits the ring on a 393 pt wide screen at M:SS.
Text(timeLeft)
    .font(.system(size: 132, weight: .semibold, design: .rounded).monospacedDigit())
    .lineLimit(1)
    .minimumScaleFactor(0.75)   // 10:00 and longer need about 104 pt
    .contentTransition(.numericText(countsDown: true))   // skip under Reduce Motion

// Phase name. 56 pt at the default text size, follows Dynamic Type.
Text(phaseName)
    .font(.system(.largeTitle, design: .rounded, weight: .semibold).scaled(by: 1.65))
    .lineLimit(1)
    .minimumScaleFactor(0.6)

// Round number. 40 pt at the default text size, follows Dynamic Type.
Text(roundText)
    .font(.system(.largeTitle, design: .rounded, weight: .semibold).scaled(by: 1.18).monospacedDigit())
    .lineLimit(1)
    .minimumScaleFactor(0.6)
```

These compile against the iOS 27.2 SDK (`swiftc -typecheck`, target iOS 27.0). Sizes need checking on a device.

Three notes on these settings:

- The time's fixed size is a deliberate exception to the `swiftui-pro` rule against forced sizes. At 132 pt it's over twice the largest Dynamic Type Large Title (60 pt), and it is bound by the ring.
- `minimumScaleFactor` is applied per string, so the digits would jump in size when a Phase crosses from `10:00` to `9:59`. Pick the size from the Phase's starting duration instead, so it holds for the whole Phase.
- `numericText` is decorative. Honor Reduce Motion, per [HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion).

### Distance

| Text | Font size | Height | 1 m | 3 m | 5 m |
| --- | --- | --- | --- | --- | --- |
| Time, M:SS, ring | 132 pt | 16.0 mm | 55.2' | 18.4' | 11.0' |
| Time, 10:00, ring | 104 pt | 12.6 mm | 43.5' | 14.5' | 8.7' |
| Time, M:SS, old flood | 157 pt | 19.1 mm | 65.6' | 21.9' | 13.1' |
| Phase name | 56 pt | 6.8 mm | 23.4' | 7.8' | 4.7' |
| Round number | 40 pt | 4.9 mm | 16.7' | 5.6' | 3.3' |

Angles are arcminutes on a 460 ppi, 3x iPhone ([iPhone 17 Pro specs](https://support.apple.com/en-us/125090)).

- **The ring costs size.** It takes the time from about 157 pt to about 132 pt, 16 percent less. That's the main trade-off of the circle. Thin the margin or stroke if distance reading suffers.
- **Legibility targets are secondhand.** ISO 9241-303 is commonly cited as 20 to 22 arcminutes, with 16 as a minimum, but I only saw this secondhand in [a W3C mailing list comment](https://lists.w3.org/Archives/Public/public-css-archive/2020Jun/0612.html), and it's aimed at desk reading. The time at 3 m is near that. 20/20 acuity corresponds to about 5 arcminutes per letter, so the Round number at 3 m is at the limit and the Phase name is only modestly above it.
- **Color does the Phase's work at distance.** The Phase name is a backup at 3 m and clearly readable at 1 to 2 m. The Cue covers the Phase change aloud anyway.

## What could not be verified

- **Apple's iPhone workout color conventions.** Apple documents the Workouts guidance above and the watchOS background rule. I found no statement of the colors the iPhone Fitness or Workout apps use during a session, so no claims about them are made here.
- **Material 3 pages.** `m3.material.io` returned only titles. Tone roles come from Material's Android docs instead. The rule linking tone differences of 40 and 50 to 3:1 and 4.5:1 was seen only in a search excerpt of a Material blog post, so it isn't relied on. All ratios are computed.
- **Material 2 dark theme page.** It also returned only a title. A search excerpt gave "Don't use bright colors for large surfaces", which would be directly relevant, but I couldn't confirm that wording, so it isn't used in the table. The vibration wording was confirmed on the Wear OS page and the codelab.
- **ISO 9241-303 and stroke-width ratios.** Paywalled or secondhand only, as noted.
- **Machado's linear RGB assumption.** Taken from the R colorspace documentation, which cites page 1294. I read the matrices on the authors' page but not that page of the paper.
- **Partial reads.** For Wilms and Oberfeld, I read the abstract and methods, not the results section. For Pathari et al., I read the abstract page, which gives no sample size. The BIOJ, Sengsoon, Penacchio, and Elliot details came through a summarizing fetch tool, and the Gnambs result from a search excerpt, so check quotes against the papers before relying on them. The WWDC history of proportional digits was also search-only and isn't relied on.
- **Real conditions.** Contrast figures assume an ideal display. They ignore glare, brightness, True Tone, and Liquid Glass. Apple says ["in bright surroundings, colors look darker and more muted"](https://developer.apple.com/design/human-interface-guidelines/color), so test in the gym. Accessibility Inspector should confirm ratios on device.
- **Calm and encouraging.** Nothing here measures these for this screen.

## Appendix: scripts and results

Run with `python3 palette.py` and `swift digits.swift`. Both use only what ships with Python and macOS.

Sanity checks at the end of the output confirm known values: black on white is 21.00, `#777777` on white is 4.48, and the first CIEDE2000 test pair from Sharma et al. (2005) gives 2.0425. I wrote that expected value from memory and did not recheck it against the dataset.

### `palette.py`

```python
#!/usr/bin/env python3
"""Temper running-screen palette checks. Stdlib only. Run: python3 palette.py

Contrast: WCAG 2.2 relative luminance and contrast ratio.
CVD: Machado, Oliveira & Fernandes 2009, severity 1.0 matrices, applied to linear RGB,
     results clipped to [0, 1].
Difference: CIEDE2000 between sRGB colors (D65, CIELAB).
"""
import itertools
import math

PROT = [[0.152286, 1.052583, -0.204868], [0.114503, 0.786281, 0.099216], [-0.003882, -0.048116, 1.051998]]
DEUT = [[0.367322, 0.860646, -0.227968], [0.280085, 0.672501, 0.047413], [-0.011820, 0.042940, 0.968881]]


def rgb(h):
    h = h.lstrip("#")
    return [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def unlin(c):
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def lum_lin(v):
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]


def lum(h):
    return lum_lin([lin(c) for c in rgb(h)])


def cr(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def lab(v_lin):
    x = 0.4124564 * v_lin[0] + 0.3575761 * v_lin[1] + 0.1804375 * v_lin[2]
    y = 0.2126729 * v_lin[0] + 0.7151522 * v_lin[1] + 0.0721750 * v_lin[2]
    z = 0.0193339 * v_lin[0] + 0.1191920 * v_lin[1] + 0.9503041 * v_lin[2]

    def f(t):
        return t ** (1 / 3) if t > 216 / 24389 else (24389 / 27 * t + 16) / 116

    fx, fy, fz = f(x / 0.95047), f(y), f(z / 1.08883)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def tone(h):
    return lab([lin(c) for c in rgb(h)])[0]


def chroma(h):
    _, a, b = lab([lin(c) for c in rgb(h)])
    return math.hypot(a, b)


def de2000(l1, l2):
    L1, a1, b1 = l1
    L2, a2, b2 = l2
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2)
    Cb = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(Cb**7 / (Cb**7 + 25**7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360 if C1p else 0
    h2p = math.degrees(math.atan2(b2, a2p)) % 360 if C2p else 0
    dL, dC = L2 - L1, C2p - C1p
    if C1p * C2p == 0:
        dh = 0
    else:
        dh = h2p - h1p
        if dh > 180:
            dh -= 360
        elif dh < -180:
            dh += 360
    dH = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dh) / 2)
    Lb, Cbp = (L1 + L2) / 2, (C1p + C2p) / 2
    if C1p * C2p == 0:
        hb = h1p + h2p
    elif abs(h1p - h2p) <= 180:
        hb = (h1p + h2p) / 2
    elif h1p + h2p < 360:
        hb = (h1p + h2p + 360) / 2
    else:
        hb = (h1p + h2p - 360) / 2
    T = (1 - 0.17 * math.cos(math.radians(hb - 30)) + 0.24 * math.cos(math.radians(2 * hb))
         + 0.32 * math.cos(math.radians(3 * hb + 6)) - 0.20 * math.cos(math.radians(4 * hb - 63)))
    dtheta = 30 * math.exp(-(((hb - 275) / 25) ** 2))
    Rc = 2 * math.sqrt(Cbp**7 / (Cbp**7 + 25**7))
    Sl = 1 + 0.015 * (Lb - 50) ** 2 / math.sqrt(20 + (Lb - 50) ** 2)
    Sc = 1 + 0.045 * Cbp
    Sh = 1 + 0.015 * Cbp * T
    Rt = -math.sin(math.radians(2 * dtheta)) * Rc
    return math.sqrt((dL / Sl) ** 2 + (dC / Sc) ** 2 + (dH / Sh) ** 2 + Rt * (dC / Sc) * (dH / Sh))


def sim(h, M):
    v = [lin(c) for c in rgb(h)]
    return [min(1, max(0, sum(M[i][j] * v[j] for j in range(3)))) for i in range(3)]


def to_hex(v):
    return "#" + "".join(f"{round(unlin(c) * 255):02X}" for c in v)


def de(a, b, M=None):
    va = sim(a, M) if M else [lin(c) for c in rgb(a)]
    vb = sim(b, M) if M else [lin(c) for c in rgb(b)]
    return de2000(lab(va), lab(vb))


PHASES = ["Prepare", "Work", "Rest", "Cooldown"]
# name -> phase -> (background, ring, track, phase-name text, time/primary text)
DIRECTIONS = {
    "A dark": {
        "Prepare": ("#101114", "#F5D06F", "#2C2E33", "#F5D06F", "#F5F5F7"),
        "Work": ("#101114", "#FF8A66", "#2C2E33", "#FF8A66", "#F5F5F7"),
        "Rest": ("#101114", "#66DCCA", "#2C2E33", "#66DCCA", "#F5F5F7"),
        "Cooldown": ("#101114", "#9DB4FF", "#2C2E33", "#9DB4FF", "#F5F5F7"),
    },
    "A increased contrast": {
        "Prepare": ("#000000", "#FFE08F", "#3D4047", "#FFE08F", "#FFFFFF"),
        "Work": ("#000000", "#FFAB91", "#3D4047", "#FFAB91", "#FFFFFF"),
        "Rest": ("#000000", "#86EBDB", "#3D4047", "#86EBDB", "#FFFFFF"),
        "Cooldown": ("#000000", "#BCCBFF", "#3D4047", "#BCCBFF", "#FFFFFF"),
    },
    "A light": {
        "Prepare": ("#F7F6F3", "#9A6F00", "#DEDCD6", "#7A5900", "#16171A"),
        "Work": ("#F7F6F3", "#AD3A1B", "#DEDCD6", "#A63716", "#16171A"),
        "Rest": ("#F7F6F3", "#007A6C", "#DEDCD6", "#006B5F", "#16171A"),
        "Cooldown": ("#F7F6F3", "#3D5BC4", "#DEDCD6", "#3552B5", "#16171A"),
    },
    "A light increased contrast": {
        "Prepare": ("#FFFFFF", "#8A6400", "#CFCDC7", "#5F4500", "#000000"),
        "Work": ("#FFFFFF", "#8F2E14", "#CFCDC7", "#7F2810", "#000000"),
        "Rest": ("#FFFFFF", "#005F54", "#CFCDC7", "#00514A", "#000000"),
        "Cooldown": ("#FFFFFF", "#2C459E", "#CFCDC7", "#263C8C", "#000000"),
    },
    "B dark": {
        "Prepare": ("#2B2210", "#F8DE9C", "#4D3F22", "#F8DE9C", "#FBF7EF"),
        "Work": ("#33191A", "#FFAD96", "#573230", "#FFAD96", "#FFF6F3"),
        "Rest": ("#0F2A28", "#8FE3D4", "#25483F", "#8FE3D4", "#F1FBF8"),
        "Cooldown": ("#182340", "#BCCBFF", "#303F66", "#BCCBFF", "#F4F6FF"),
    },
    "B increased contrast": {
        "Prepare": ("#1C1609", "#FFEDC2", "#5C4C2A", "#FFEDC2", "#FFFFFF"),
        "Work": ("#220F10", "#FFCFC0", "#663B38", "#FFCFC0", "#FFFFFF"),
        "Rest": ("#081C1A", "#ABF0E4", "#2C554B", "#ABF0E4", "#FFFFFF"),
        "Cooldown": ("#0F172D", "#D0DBFF", "#394A75", "#D0DBFF", "#FFFFFF"),
    },
    "B light": {
        "Prepare": ("#F6EBD3", "#946A00", "#E0D0AE", "#6E5000", "#1E1704"),
        "Work": ("#F9E4DD", "#A1341A", "#E8C8BD", "#962F12", "#2A0F08"),
        "Rest": ("#D9F0EA", "#006E61", "#B3D8CF", "#005F54", "#04201C"),
        "Cooldown": ("#E2E7F8", "#3651B4", "#C4CDEA", "#2F47A2", "#0E1630"),
    },
    "B light increased contrast": {
        "Prepare": ("#FBF4E3", "#7F5B00", "#D2C09A", "#574000", "#000000"),
        "Work": ("#FDEFEA", "#862A12", "#DDB6A9", "#74230E", "#000000"),
        "Rest": ("#E9F7F3", "#00574D", "#A3CCC2", "#004A42", "#000000"),
        "Cooldown": ("#EEF1FB", "#294192", "#B4BFE2", "#223781", "#000000"),
    },
}

OLD = {"Prepare": (1.0, 0.8, 0.0), "Work": (0.78, 0.07, 0.09), "Rest": (0.2, 0.82, 0.48), "Cooldown": (0.04, 0.28, 0.72)}


def h8(t):
    return "#" + "".join(f"{round(c * 255):02X}" for c in t)


print("## Old flood, for comparison (prototype/screens App.swift)")
print("Phase | fill | L* | C* | R/(R+G+B) | white on fill | black on fill")
for p, t in OLD.items():
    h = h8(t)
    print(f"{p} | {h} | {tone(h):.1f} | {chroma(h):.1f} | {t[0] / sum(t):.3f} | {cr(h, '#FFFFFF'):.2f} | {cr(h, '#000000'):.2f}")
o = h8(OLD["Work"]), h8(OLD["Rest"])
print(f"Old Work/Rest dE00 normal {de(*o):.1f}, deut {de(*o, DEUT):.1f} ({to_hex(sim(o[0], DEUT))}/{to_hex(sim(o[1], DEUT))}), "
      f"prot {de(*o, PROT):.1f} ({to_hex(sim(o[0], PROT))}/{to_hex(sim(o[1], PROT))})")
print()

ok = True
for name, d in DIRECTIONS.items():
    print(f"## {name}")
    print("Phase | bg | ring | track | name | time | time:bg | name:bg | ring:bg | ring:track | track:bg | bg L* C* | ring L* C*")
    for p in PHASES:
        bg, ring, track, nm, tm = d[p]
        v = (cr(tm, bg), cr(nm, bg), cr(ring, bg), cr(ring, track), cr(track, bg))
        print(f"{p} | {bg} | {ring} | {track} | {nm} | {tm} | {v[0]:.2f} | {v[1]:.2f} | {v[2]:.2f} | {v[3]:.2f} | {v[4]:.2f} | {tone(bg):.0f} {chroma(bg):.0f} | {tone(ring):.0f} {chroma(ring):.0f}")
        if v[0] < 7 or v[1] < 4.5 or v[2] < 3 or v[3] < 3:
            ok = False
            print(f"   FAIL threshold in {name}/{p}")
    print("Ring pairs dE00 normal / deuteranopia / protanopia, and |dL*| normal:")
    for a, b in itertools.combinations(PHASES, 2):
        ra, rb = d[a][1], d[b][1]
        print(f"  {a}/{b}: {de(ra, rb):.1f} / {de(ra, rb, DEUT):.1f} / {de(ra, rb, PROT):.1f}  dL* {abs(tone(ra) - tone(rb)):.1f}")
    bga, bgb = d["Work"][0], d["Rest"][0]
    if bga != bgb:
        print(f"Bg Work/Rest dE00 normal {de(bga, bgb):.1f} deut {de(bga, bgb, DEUT):.1f} prot {de(bga, bgb, PROT):.1f}")
    for lab_, M in (("deut", DEUT), ("prot", PROT)):
        w, r = d["Work"][1], d["Rest"][1]
        print(f"Simulated {lab_}: Work ring {w} -> {to_hex(sim(w, M))}; Rest ring {r} -> {to_hex(sim(r, M))}; "
              f"ring:bg after sim Work {cr(to_hex(sim(w, M)), to_hex(sim(d['Work'][0], M))):.2f} Rest {cr(to_hex(sim(r, M)), to_hex(sim(d['Rest'][0], M))):.2f}")
    print()
print("## Sensitivity: matrices applied to gamma-encoded sRGB instead of linear RGB, Work/Rest rings")


def de_gamma(a, b, M):
    def g(h):
        v = rgb(h)
        return [lin(min(1, max(0, sum(M[i][j] * v[j] for j in range(3))))) for i in range(3)]

    return de2000(lab(g(a)), lab(g(b)))


for name, d in DIRECTIONS.items():
    w, r = d["Work"][1], d["Rest"][1]
    print(f"{name}: deut {de_gamma(w, r, DEUT):.1f} prot {de_gamma(w, r, PROT):.1f}")
print()
print("## Visual angle on a 460 ppi 3x iPhone (1 pt = 0.1656 mm). Digit/cap height from measured 0.734 em (Rounded semibold).")
MM = 25.4 / (460 / 3)
print("font pt | height mm | arcmin at 1 m | 2 m | 3 m | 5 m")
for pt in (34, 40, 56, 64, 104, 132, 157):
    h = pt * 0.734 * MM
    print(f"{pt} | {h:.1f} | " + " | ".join(f"{math.degrees(2 * math.atan(h / 2 / (m * 1000))) * 60:.1f}" for m in (1, 2, 3, 5)))
print("Ring stroke 22 pt:", ", ".join(f"{m} m {math.degrees(2 * math.atan(22 * MM / 2 / (m * 1000))) * 60:.1f} arcmin" for m in (1, 3, 5)))
for dist in (0.4, 3):
    print(f"Screen 71.5 x 150 mm at {dist} m: {math.degrees(2 * math.atan(35.75 / (dist * 1000))):.1f} x {math.degrees(2 * math.atan(75 / (dist * 1000))):.1f} degrees")
print()
print("## Largest time font in a ring on a 393 pt wide screen (16 pt margin, 22 pt stroke, 8 pt inner padding)")
D = 393 - 2 * 16 - 2 * 22 - 2 * 8
for label, w, hh in (("0:45 Rounded semibold", 2.164, 0.734), ("10:00 Rounded semibold", 2.795, 0.734), ("0:45 Pro semibold", 2.125, 0.729), ("10:00 Pro semibold", 2.757, 0.729)):
    print(f"{label}: {D / math.hypot(w, hh):.0f} pt")
print(f"Flood prototype, 0:45 Rounded heavy on 361 pt: {361 / 2.299:.0f} pt, 170 pt request scaled to fit")
print()
print("ALL THRESHOLDS PASS" if ok else "SOME THRESHOLDS FAIL")
print()
print("## Sanity checks")
print(f"black/white {cr('#000000', '#FFFFFF'):.2f} (expect 21.00); #777777/white {cr('#777777', '#FFFFFF'):.2f} (expect 4.48)")
# Sharma et al. 2005 CIEDE2000 test pair 1 -> 2.0425
print(f"CIEDE2000 Sharma pair 1 {de2000((50, 2.6772, -79.7751), (50, 0, -82.7485)):.4f} (expect 2.0425)")
print(f"Machado row sums prot {[round(sum(r), 6) for r in PROT]} deut {[round(sum(r), 6) for r in DEUT]}")
```

### `palette.py` output

```text
## Old flood, for comparison (prototype/screens App.swift)
Phase | fill | L* | C* | R/(R+G+B) | white on fill | black on fill
Prepare | #FFCC00 | 84.2 | 85.3 | 0.556 | 1.51 | 13.89
Work | #C71217 | 42.2 | 80.4 | 0.830 | 5.95 | 3.53
Rest | #33D17A | 74.6 | 67.3 | 0.133 | 1.99 | 10.54
Cooldown | #0A47B8 | 34.0 | 70.0 | 0.038 | 8.06 | 2.61
Old Work/Rest dE00 normal 78.0, deut 23.9 (#7F7106/#BEB280), prot 43.3 (#554B13/#D1C074)

## A dark
Phase | bg | ring | track | name | time | time:bg | name:bg | ring:bg | ring:track | track:bg | bg L* C* | ring L* C*
Prepare | #101114 | #F5D06F | #2C2E33 | #F5D06F | #F5F5F7 | 17.34 | 12.71 | 12.71 | 9.14 | 1.39 | 5 2 | 85 52
Work | #101114 | #FF8A66 | #2C2E33 | #FF8A66 | #F5F5F7 | 17.34 | 8.16 | 8.16 | 5.87 | 1.39 | 5 2 | 70 57
Rest | #101114 | #66DCCA | #2C2E33 | #66DCCA | #F5F5F7 | 17.34 | 11.38 | 11.38 | 8.19 | 1.39 | 5 2 | 81 38
Cooldown | #101114 | #9DB4FF | #2C2E33 | #9DB4FF | #F5F5F7 | 17.34 | 9.36 | 9.36 | 6.73 | 1.39 | 5 2 | 74 41
Ring pairs dE00 normal / deuteranopia / protanopia, and |dL*| normal:
  Prepare/Work: 30.0 / 9.5 / 15.9  dL* 15.1
  Prepare/Rest: 34.5 / 29.9 / 21.7  dL* 3.9
  Prepare/Cooldown: 50.3 / 51.9 / 49.9  dL* 10.6
  Work/Rest: 53.0 / 27.5 / 21.2  dL* 11.1
  Work/Cooldown: 40.8 / 48.4 / 43.6  dL* 4.5
  Rest/Cooldown: 32.2 / 18.3 / 25.8  dL* 6.7
Simulated deut: Work ring #FF8A66 -> #C5B464; Rest ring #66DCCA -> #C0C3CC; ring:bg after sim Work 9.07 Rest 10.72
Simulated prot: Work ring #FF8A66 -> #A89B63; Rest ring #66DCCA -> #D3D1C9; ring:bg after sim Work 6.77 Rest 12.35

## A increased contrast
Phase | bg | ring | track | name | time | time:bg | name:bg | ring:bg | ring:track | track:bg | bg L* C* | ring L* C*
Prepare | #000000 | #FFE08F | #3D4047 | #FFE08F | #FFFFFF | 21.00 | 16.31 | 16.31 | 8.06 | 2.02 | 0 0 | 90 43
Work | #000000 | #FFAB91 | #3D4047 | #FFAB91 | #FFFFFF | 21.00 | 11.49 | 11.49 | 5.68 | 2.02 | 0 0 | 78 38
Rest | #000000 | #86EBDB | #3D4047 | #86EBDB | #FFFFFF | 21.00 | 14.92 | 14.92 | 7.38 | 2.02 | 0 0 | 87 33
Cooldown | #000000 | #BCCBFF | #3D4047 | #BCCBFF | #FFFFFF | 21.00 | 13.12 | 13.12 | 6.49 | 2.02 | 0 0 | 82 28
Ring pairs dE00 normal / deuteranopia / protanopia, and |dL*| normal:
  Prepare/Work: 25.3 / 9.3 / 13.7  dL* 12.6
  Prepare/Rest: 31.4 / 27.6 / 19.8  dL* 3.3
  Prepare/Cooldown: 42.7 / 43.8 / 42.2  dL* 7.9
  Work/Rest: 45.5 / 23.0 / 15.7  dL* 9.3
  Work/Cooldown: 33.4 / 38.2 / 33.9  dL* 4.6
  Rest/Cooldown: 28.2 / 13.8 / 20.7  dL* 4.6
Simulated deut: Work ring #FFAB91 -> #D3C690; Rest ring #86EBDB -> #D2D4DC; ring:bg after sim Work 12.25 Rest 14.19
Simulated prot: Work ring #FFAB91 -> #BFB58F; Rest ring #86EBDB -> #E3E1DA; ring:bg after sim Work 10.22 Rest 16.05

## A light
Phase | bg | ring | track | name | time | time:bg | name:bg | ring:bg | ring:track | track:bg | bg L* C* | ring L* C*
Prepare | #F7F6F3 | #9A6F00 | #DEDCD6 | #7A5900 | #16171A | 16.59 | 5.97 | 4.18 | 3.29 | 1.27 | 97 2 | 50 57
Work | #F7F6F3 | #AD3A1B | #DEDCD6 | #A63716 | #16171A | 16.59 | 6.11 | 5.72 | 4.51 | 1.27 | 97 2 | 41 63
Rest | #F7F6F3 | #007A6C | #DEDCD6 | #006B5F | #16171A | 16.59 | 5.95 | 4.86 | 3.83 | 1.27 | 97 2 | 46 32
Cooldown | #F7F6F3 | #3D5BC4 | #DEDCD6 | #3552B5 | #16171A | 16.59 | 6.42 | 5.56 | 4.39 | 1.27 | 97 2 | 42 63
Ring pairs dE00 normal / deuteranopia / protanopia, and |dL*| normal:
  Prepare/Work: 26.4 / 6.9 / 13.0  dL* 8.6
  Prepare/Rest: 36.5 / 29.5 / 21.7  dL* 4.2
  Prepare/Cooldown: 56.0 / 59.2 / 55.8  dL* 7.9
  Work/Rest: 51.6 / 26.6 / 20.6  dL* 4.4
  Work/Cooldown: 43.8 / 55.9 / 50.7  dL* 0.7
  Rest/Cooldown: 35.8 / 22.7 / 29.9  dL* 3.7
Simulated deut: Work ring #AD3A1B -> #786B15; Rest ring #007A6C -> #66686D; ring:bg after sim Work 4.97 Rest 5.16
Simulated prot: Work ring #AD3A1B -> #5C5116; Rest ring #007A6C -> #74726B; ring:bg after sim Work 7.35 Rest 4.45

## A light increased contrast
Phase | bg | ring | track | name | time | time:bg | name:bg | ring:bg | ring:track | track:bg | bg L* C* | ring L* C*
Prepare | #FFFFFF | #8A6400 | #CFCDC7 | #5F4500 | #000000 | 21.00 | 8.98 | 5.38 | 3.38 | 1.59 | 100 0 | 45 53
Work | #FFFFFF | #8F2E14 | #CFCDC7 | #7F2810 | #000000 | 21.00 | 9.49 | 8.17 | 5.14 | 1.59 | 100 0 | 34 55
Rest | #FFFFFF | #005F54 | #CFCDC7 | #00514A | #000000 | 21.00 | 9.23 | 7.60 | 4.78 | 1.59 | 100 0 | 36 27
Cooldown | #FFFFFF | #2C459E | #CFCDC7 | #263C8C | #000000 | 21.00 | 9.96 | 8.56 | 5.39 | 1.59 | 100 0 | 32 56
Ring pairs dE00 normal / deuteranopia / protanopia, and |dL*| normal:
  Prepare/Work: 25.7 / 9.2 / 14.1  dL* 11.3
  Prepare/Rest: 34.9 / 29.3 / 21.7  dL* 9.3
  Prepare/Cooldown: 54.2 / 57.0 / 53.5  dL* 12.6
  Work/Rest: 46.9 / 24.7 / 17.5  dL* 2.0
  Work/Cooldown: 41.2 / 52.3 / 46.7  dL* 1.3
  Rest/Cooldown: 33.3 / 21.5 / 27.6  dL* 3.3
Simulated deut: Work ring #8F2E14 -> #62570F; Rest ring #005F54 -> #4F5055; ring:bg after sim Work 7.27 Rest 8.04
Simulated prot: Work ring #8F2E14 -> #4A4110; Rest ring #005F54 -> #5A5954; ring:bg after sim Work 10.22 Rest 7.02

## B dark
Phase | bg | ring | track | name | time | time:bg | name:bg | ring:bg | ring:track | track:bg | bg L* C* | ring L* C*
Prepare | #2B2210 | #F8DE9C | #4D3F22 | #F8DE9C | #FBF7EF | 14.68 | 11.89 | 11.89 | 7.77 | 1.53 | 14 13 | 89 36
Work | #33191A | #FFAD96 | #573230 | #FFAD96 | #FFF6F3 | 15.24 | 9.01 | 9.01 | 6.13 | 1.47 | 12 14 | 78 36
Rest | #0F2A28 | #8FE3D4 | #25483F | #8FE3D4 | #F1FBF8 | 14.39 | 10.21 | 10.21 | 6.79 | 1.50 | 15 11 | 85 29
Cooldown | #182340 | #BCCBFF | #303F66 | #BCCBFF | #F4F6FF | 14.39 | 9.70 | 9.70 | 6.47 | 1.50 | 14 21 | 82 28
Ring pairs dE00 normal / deuteranopia / protanopia, and |dL*| normal:
  Prepare/Work: 24.1 / 7.4 / 11.8  dL* 11.1
  Prepare/Rest: 28.3 / 24.4 / 17.3  dL* 4.5
  Prepare/Cooldown: 40.2 / 41.3 / 39.7  dL* 7.0
  Work/Rest: 43.5 / 20.9 / 13.6  dL* 6.7
  Work/Cooldown: 32.7 / 37.3 / 32.8  dL* 4.1
  Rest/Cooldown: 27.3 / 14.6 / 20.6  dL* 2.6
Bg Work/Rest dE00 normal 29.7 deut 8.6 prot 4.2
Simulated deut: Work ring #FFAD96 -> #D4C895; Rest ring #8FE3D4 -> #CDCFD5; ring:bg after sim Work 9.45 Rest 9.95
Simulated prot: Work ring #FFAD96 -> #C0B794; Rest ring #8FE3D4 -> #DCDAD3; ring:bg after sim Work 8.38 Rest 10.54

## B increased contrast
Phase | bg | ring | track | name | time | time:bg | name:bg | ring:bg | ring:track | track:bg | bg L* C* | ring L* C*
Prepare | #1C1609 | #FFEDC2 | #5C4C2A | #FFEDC2 | #FFFFFF | 17.98 | 15.53 | 15.53 | 7.19 | 2.16 | 8 8 | 94 23
Work | #220F10 | #FFCFC0 | #663B38 | #FFCFC0 | #FFFFFF | 18.36 | 13.06 | 13.06 | 6.65 | 1.97 | 6 10 | 87 20
Rest | #081C1A | #ABF0E4 | #2C554B | #ABF0E4 | #FFFFFF | 17.63 | 13.70 | 13.70 | 6.51 | 2.11 | 9 9 | 90 24
Cooldown | #0F172D | #D0DBFF | #394A75 | #D0DBFF | #FFFFFF | 17.79 | 12.92 | 12.92 | 6.33 | 2.04 | 8 17 | 88 19
Ring pairs dE00 normal / deuteranopia / protanopia, and |dL*| normal:
  Prepare/Work: 17.9 / 5.9 / 8.5  dL* 7.3
  Prepare/Rest: 24.2 / 19.6 / 13.2  dL* 4.1
  Prepare/Cooldown: 30.8 / 31.8 / 30.3  dL* 6.6
  Work/Rest: 36.8 / 15.3 / 8.2  dL* 3.3
  Work/Cooldown: 24.4 / 27.2 / 23.3  dL* 0.8
  Rest/Cooldown: 24.2 / 10.7 / 15.7  dL* 2.5
Bg Work/Rest dE00 normal 23.9 deut 5.6 prot 2.6
Simulated deut: Work ring #FFCFC0 -> #E5DDC0; Rest ring #ABF0E4 -> #DDDFE5; ring:bg after sim Work 13.32 Rest 13.33
Simulated prot: Work ring #FFCFC0 -> #DAD4BF; Rest ring #ABF0E4 -> #EAE8E4; ring:bg after sim Work 12.62 Rest 14.22

## B light
Phase | bg | ring | track | name | time | time:bg | name:bg | ring:bg | ring:track | track:bg | bg L* C* | ring L* C*
Prepare | #F6EBD3 | #946A00 | #E0D0AE | #6E5000 | #1E1704 | 15.04 | 6.31 | 4.11 | 3.19 | 1.29 | 93 13 | 48 55
Work | #F9E4DD | #A1341A | #E8C8BD | #962F12 | #2A0F08 | 14.67 | 6.33 | 5.68 | 4.44 | 1.28 | 92 9 | 38 59
Rest | #D9F0EA | #006E61 | #B3D8CF | #005F54 | #04201C | 14.33 | 6.37 | 5.17 | 4.01 | 1.29 | 93 9 | 41 30
Cooldown | #E2E7F8 | #3651B4 | #C4CDEA | #2F47A2 | #0E1630 | 14.47 | 6.69 | 5.69 | 4.43 | 1.28 | 92 9 | 38 61
Ring pairs dE00 normal / deuteranopia / protanopia, and |dL*| normal:
  Prepare/Work: 26.4 / 8.1 / 13.8  dL* 9.7
  Prepare/Rest: 36.0 / 29.2 / 21.5  dL* 6.5
  Prepare/Cooldown: 55.2 / 58.5 / 54.9  dL* 10.0
  Work/Rest: 50.1 / 25.4 / 18.6  dL* 3.2
  Work/Cooldown: 42.4 / 54.3 / 48.5  dL* 0.3
  Rest/Cooldown: 35.0 / 22.4 / 29.2  dL* 3.5
Bg Work/Rest dE00 normal 19.7 deut 6.4 prot 3.3
Simulated deut: Work ring #A1341A -> #6F6215; Rest ring #006E61 -> #5C5D62; ring:bg after sim Work 5.07 Rest 5.45
Simulated prot: Work ring #A1341A -> #544A16; Rest ring #006E61 -> #686761; ring:bg after sim Work 7.11 Rest 4.85

## B light increased contrast
Phase | bg | ring | track | name | time | time:bg | name:bg | ring:bg | ring:track | track:bg | bg L* C* | ring L* C*
Prepare | #FBF4E3 | #7F5B00 | #D2C09A | #574000 | #000000 | 19.15 | 8.96 | 5.63 | 3.46 | 1.63 | 96 9 | 41 50
Work | #FDEFEA | #862A12 | #DDB6A9 | #74230E | #000000 | 18.71 | 9.41 | 7.95 | 4.82 | 1.65 | 95 6 | 31 52
Rest | #E9F7F3 | #00574D | #A3CCC2 | #004A42 | #000000 | 19.06 | 9.26 | 7.72 | 4.85 | 1.59 | 96 5 | 33 25
Cooldown | #EEF1FB | #294192 | #B4BFE2 | #223781 | #000000 | 18.61 | 9.64 | 8.21 | 5.07 | 1.62 | 95 5 | 30 51
Ring pairs dE00 normal / deuteranopia / protanopia, and |dL*| normal:
  Prepare/Work: 24.2 / 7.8 / 12.5  dL* 9.9
  Prepare/Rest: 33.8 / 28.2 / 21.1  dL* 8.6
  Prepare/Cooldown: 51.8 / 54.5 / 51.2  dL* 11.0
  Work/Rest: 45.5 / 24.2 / 16.7  dL* 1.3
  Work/Cooldown: 40.1 / 50.4 / 44.9  dL* 1.1
  Rest/Cooldown: 32.0 / 20.8 / 26.4  dL* 2.4
Bg Work/Rest dE00 normal 13.1 deut 4.4 prot 2.3
Simulated deut: Work ring #862A12 -> #5C510D; Rest ring #00574D -> #484A4E; ring:bg after sim Work 7.16 Rest 8.00
Simulated prot: Work ring #862A12 -> #453D0E; Rest ring #00574D -> #52514D; ring:bg after sim Work 9.56 Rest 7.29

## Sensitivity: matrices applied to gamma-encoded sRGB instead of linear RGB, Work/Rest rings
A dark: deut 30.4 prot 22.1
A increased contrast: deut 24.9 prot 16.1
A light: deut 32.9 prot 22.2
A light increased contrast: deut 29.5 prot 18.6
B dark: deut 22.1 prot 13.8
B increased contrast: deut 16.2 prot 8.4
B light: deut 31.0 prot 19.9
B light increased contrast: deut 28.3 prot 17.6

## Visual angle on a 460 ppi 3x iPhone (1 pt = 0.1656 mm). Digit/cap height from measured 0.734 em (Rounded semibold).
font pt | height mm | arcmin at 1 m | 2 m | 3 m | 5 m
34 | 4.1 | 14.2 | 7.1 | 4.7 | 2.8
40 | 4.9 | 16.7 | 8.4 | 5.6 | 3.3
56 | 6.8 | 23.4 | 11.7 | 7.8 | 4.7
64 | 7.8 | 26.8 | 13.4 | 8.9 | 5.4
104 | 12.6 | 43.5 | 21.7 | 14.5 | 8.7
132 | 16.0 | 55.2 | 27.6 | 18.4 | 11.0
157 | 19.1 | 65.6 | 32.8 | 21.9 | 13.1
Ring stroke 22 pt: 1 m 12.5 arcmin, 3 m 4.2 arcmin, 5 m 2.5 arcmin
Screen 71.5 x 150 mm at 0.4 m: 10.2 x 21.2 degrees
Screen 71.5 x 150 mm at 3 m: 1.4 x 2.9 degrees

## Largest time font in a ring on a 393 pt wide screen (16 pt margin, 22 pt stroke, 8 pt inner padding)
0:45 Rounded semibold: 132 pt
10:00 Rounded semibold: 104 pt
0:45 Pro semibold: 134 pt
10:00 Pro semibold: 106 pt
Flood prototype, 0:45 Rounded heavy on 361 pt: 157 pt, 170 pt request scaled to fit

ALL THRESHOLDS PASS

## Sanity checks
black/white 21.00 (expect 21.00); #777777/white 4.48 (expect 4.48)
CIEDE2000 Sharma pair 1 2.0425 (expect 2.0425)
Machado row sums prot [1.000001, 1.0, 1.0] deut [1.0, 0.999999, 1.000001]
```

### `digits.swift`

```swift
// Measures SF digit widths and stem thickness using AppKit on this Mac.
// Mac and iOS share the SF family, but verify the final size on a device.
import AppKit

func make(_ size: CGFloat, _ w: NSFont.Weight, rounded: Bool, tnum: Bool) -> NSFont {
    let base = tnum ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: w) : NSFont.systemFont(ofSize: size, weight: w)
    guard rounded, let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) else { return base }
    return f
}

func width(_ s: String, _ f: NSFont) -> CGFloat {
    NSAttributedString(string: s, attributes: [.font: f]).size().width
}

// Ink width of the "1" stem along its mid-height row, in em/1000, plus ink height of "0".
func ink(_ ch: String, _ f: NSFont) -> (midRun: Int, height: Int) {
    let side = 1600
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 1, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceWhite, bytesPerRow: side, bitsPerPixel: 8)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSColor.black.setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
    NSAttributedString(string: ch, attributes: [.font: f, .foregroundColor: NSColor.white]).draw(at: NSPoint(x: 200, y: 200))
    NSGraphicsContext.restoreGraphicsState()
    let p = rep.bitmapData!
    var top = side, bottom = -1
    for y in 0..<side { for x in 0..<side where p[y * side + x] > 127 { top = min(top, y); bottom = max(bottom, y); break } }
    let mid = (top + bottom) / 2
    let run = (0..<side).filter { p[mid * side + $0] > 127 }.count
    return (run, bottom - top + 1)
}

let weights: [(String, NSFont.Weight)] = [("thin", .thin), ("light", .light), ("regular", .regular), ("medium", .medium), ("semibold", .semibold), ("bold", .bold), ("heavy", .heavy), ("black", .black)]

for rounded in [false, true] {
    print(rounded ? "== SF Pro Rounded" : "== SF Pro")
    print("weight    default-digit-range  tnum-digit-range  '0:45'/em '10:00'/em  stem'1'/em  height'0'/em  stem/height")
    for (name, w) in weights {
        let p = make(1000, w, rounded: rounded, tnum: false)
        let m = make(1000, w, rounded: rounded, tnum: true)
        let pw = "0123456789".map { width(String($0), p) / 1000 }
        let mw = "0123456789".map { width(String($0), m) / 1000 }
        let i1 = ink("1", m), i0 = ink("0", m)
        let stem = Double(i1.midRun) / 1000, h = Double(i0.height) / 1000
        print(String(format: "%@ %.3f-%.3f  %.3f-%.3f  %.3f %.3f  %.3f  %.3f  %.3f",
            name.padding(toLength: 9, withPad: " ", startingAt: 0), pw.min()!, pw.max()!, mw.min()!, mw.max()!,
            width("0:45", m) / 1000, width("10:00", m) / 1000, stem, h, stem / h))
    }
}
```

### `digits.swift` output

Columns are fractions of the em. "Stem" is the ink width across the `1` at mid-height, and "height" is the ink height of the `0`.

```text
== SF Pro
weight    default-digit-range  tnum-digit-range  '0:45'/em '10:00'/em  stem'1'/em  height'0'/em  stem/height
thin      0.392-0.583  0.591-0.591  1.976 2.567  0.038  0.725  0.052
light     0.421-0.601  0.599-0.599  2.006 2.604  0.065  0.727  0.089
regular   0.443-0.617  0.604-0.604  2.028 2.633  0.086  0.729  0.118
medium    0.457-0.630  0.620-0.620  2.085 2.705  0.108  0.729  0.148
semibold  0.467-0.639  0.631-0.631  2.125 2.757  0.124  0.729  0.170
bold      0.480-0.656  0.647-0.647  2.182 2.829  0.146  0.729  0.200
heavy     0.500-0.682  0.670-0.670  2.263 2.933  0.179  0.730  0.245
black     0.517-0.705  0.689-0.689  2.335 3.024  0.207  0.731  0.283
== SF Pro Rounded
weight    default-digit-range  tnum-digit-range  '0:45'/em '10:00'/em  stem'1'/em  height'0'/em  stem/height
thin      0.393-0.583  0.582-0.582  1.988 2.570  0.039  0.726  0.054
light     0.422-0.596  0.595-0.595  2.033 2.628  0.065  0.727  0.089
regular   0.443-0.606  0.604-0.604  2.067 2.672  0.086  0.729  0.118
medium    0.457-0.624  0.620-0.620  2.122 2.742  0.108  0.731  0.148
semibold  0.467-0.638  0.632-0.632  2.164 2.795  0.125  0.734  0.170
bold      0.480-0.656  0.647-0.647  2.219 2.866  0.147  0.737  0.199
heavy     0.499-0.681  0.669-0.669  2.299 2.968  0.179  0.741  0.242
black     0.517-0.706  0.689-0.689  2.370 3.060  0.208  0.745  0.279
```
