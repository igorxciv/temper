# App Store listing

The text of Temper's App Store page, kept here so a change to it is reviewed like code. App Store Connect is still where it's published: paste each file into its field by hand. `make listing`, part of `make check` and CI, holds every field to App Store Connect's limits.

The listing uses the words people search for, such as HIIT, Tabata and timer, even though `GLOSSARY.md` keeps them out of the app.

## Fields

| File in `en-US/` | App Store Connect field | Limit |
| --- | --- | --- |
| `name.txt` | Name | 30 characters |
| `subtitle.txt` | Subtitle | 30 characters |
| `promotional_text.txt` | Promotional Text | 170 characters, changeable without a new version |
| `description.txt` | Description | 4000 characters |
| `keywords.txt` | Keywords | 100 characters |

Keywords are comma-separated with no space after a comma. Apple already indexes every word of the name, the subtitle and the category, so a keyword that repeats one of them, or is only its plural, wastes characters. `make listing` catches a repeat and a plural made with a final "s", but not one made with "es", such as "boxes". Don't use competitors' app names or other trademarks as keywords. That's why the list has "watch" rather than "Apple Watch".

Keep prices and the word "Free" out of the name, subtitle and screenshots: guideline 2.3.7 bars pricing information in metadata. The description and promotional text are where the promise goes.

## Decided here

- **Support URL:** https://igorxciv.github.io/temper/
- **Privacy Policy URL:** https://igorxciv.github.io/temper/privacy/
- **Primary category:** Health & Fitness. **Secondary:** Sports, where boxing and rounds timers sit.
- **Price:** Free, with no in-app purchases. Temper has no StoreKit code.

### Open decision

"Everything free today stays free." in `description.txt` promises that no 1.0 feature moves behind a paywall later. That's the owner's call. Delete the line if the promise isn't made.

## App Privacy

Answer **Data Not Collected**. Apple counts data as collected only once it's sent off the device. Temper has no network code (`make lint` fails on any) and no third-party code. Speech, Describe and Health readings are all handled on the device. Crash reports that users opt to share through iOS Analytics are collected by Apple, and Apple says developers aren't responsible for disclosing those. `Temper/PrivacyInfo.xcprivacy` declares no collected data and no tracking, so the label and the manifest agree.

Check again before every release that nothing has added a crash reporter, an SDK or a network call.

## Age rating

Answer **None** or **No** to every question, which gives 4+:

- No unrestricted web access. The Privacy Policy and Contact Support rows open Safari and Mail, outside the app.
- No user-generated content, messaging, advertising, gambling, contests or loot boxes. Presets stay on the device.
- **Medical or Treatment Information:** No. Temper gives no diagnosis or guidance about health conditions.
- **Health or Wellness Topics:** No. Apple's examples are calorie tracking, dieting advice and exercise recommendations. Temper times the Workout the owner sets and recommends none. If App Review disagrees, Yes raises the rating to 9+.

## Screenshots

The required set is the 6.9" iPhone, portrait, 1320 × 2868: the iPhone 18 Pro Max Simulator captures at that size. App Store Connect scales it down for smaller iPhones. Temper ships a Watch app, so Apple asks for Watch screenshots too, all at one size, for example 416 × 496 from a 46 mm Series 11.

The finished images are in `Screenshots/en-US/`. Upload `1-describe.png` to `5-presets.png` to the 6.9" iPhone set in that order, and `watch-1-running.png` to the Apple Watch set. They lead with what no competitor has:

| File | Caption | Shows |
| --- | --- | --- |
| `1-describe.png` | Say it. Temper plans it. | Describe, with the Plan Apple Intelligence made of "4 rounds of 40 seconds of Burpees, 40 seconds of Squats and 20 seconds of rest" |
| `2-work.png` | Readable from across the room | That Plan's first Work, named Burpees |
| `3-live-activity.png` | Stays on your Lock Screen | The Live Activity on the Lock Screen |
| `4-watch.png` | Heart rate and Zone on your wrist | The iPhone and the Watch on the same Work, at 158 bpm in Zone 4 |
| `5-presets.png` | Presets, one tap away | Setup with the Preset menu open |

Everything is the real app in the Simulator, staged with the DEBUG launch arguments in `Temper/DebugLaunch.swift`. The one exception is the Watch's heart rate: a Watch Simulator can't run the iPhone's Workout, so its screen shows a sample Work with a sample reading (`TemperWatch/WatchDebugLaunch.swift`).

To make them again, after changing a screen or a caption:

```sh
brew install cameroncooke/axe/axe   # once: taps and the lock button in the Simulator
AppStore/Screenshots/capture.sh /tmp/temper-raw
swift AppStore/Screenshots/compose.swift /tmp/temper-raw AppStore/Screenshots/en-US
```

`capture.sh` stages and captures each screen. `compose.swift` puts each capture under its caption, on the color of the Phase it shows, at 1320 × 2868 with no alpha channel, as App Store Connect requires. Captions and colors are at the top of `compose.swift`. Look over each image before uploading it: the first launch of Describe can make a different Plan, and Apple's model may change.
