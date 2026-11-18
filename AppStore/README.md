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
- **Price:** Free, with three consumable tips in Settings that unlock nothing: `tip.small`, `tip.medium` and `tip.large`, named "Small Tip", "Medium Tip" and "Large Tip", at about $1.99, $4.99 and $9.99. Create them in App Store Connect with those product IDs, each with a review screenshot of the tip jar that Settings' Leave a Tip button opens, and submit them with the build. They don't load in production until the Paid Applications Agreement and the tax and banking forms are done. Enroll in the App Store Small Business Program so Apple keeps 15%. `TemperTests/Temper.storekit` mirrors the three for the Simulator and the tests, so change both together.

### Open decision

"Everything free today stays free." in `description.txt` promises that no 1.0 feature moves behind a paywall later. That's the owner's call. Delete the line if the promise isn't made.

## App Privacy

Answer **Data Not Collected**. Apple counts data as collected only once it's sent off the device. Temper has no network code (`make lint` fails on any) and no third-party code. Speech, Describe and Health readings are all handled on the device. Tips go through Apple's StoreKit, and Temper sends and keeps nothing about them, so purchase history isn't collected by Temper either. Crash reports that users opt to share through iOS Analytics are collected by Apple, and Apple says developers aren't responsible for disclosing those. `Temper/PrivacyInfo.xcprivacy` declares no collected data and no tracking, so the label and the manifest agree.

Check again before every release that nothing has added a crash reporter, an SDK or a network call.

## Age rating

Answer **None** or **No** to every question, which gives 4+:

- No unrestricted web access. The Privacy Policy and Contact Support rows open Safari and Mail, outside the app.
- No user-generated content, messaging, advertising, gambling, contests or loot boxes. Presets stay on the device.
- **Medical or Treatment Information:** No. Temper gives no diagnosis or guidance about health conditions.
- **Health or Wellness Topics:** No. Apple's examples are calorie tracking, dieting advice and exercise recommendations. Temper times the Workout the owner sets and recommends none. If App Review disagrees, Yes raises the rating to 9+.

## Screenshots

The required set is the 6.9" iPhone, portrait, 1320 × 2868: the iPhone 18 Pro Max Simulator captures at that size. App Store Connect scales it down for smaller iPhones. Temper ships a Watch app, so Apple asks for Watch screenshots too, all at one size, for example 416 × 496 from a 46 mm Series 11.

Lead with what no competitor has, in this order. The captions are drafts.

| # | Shows | Caption | How to stage it |
| --- | --- | --- | --- |
| 1 | Describe: a spoken Workout turned into a Plan outline | Say it. Temper plans it. | An iPhone with Apple Intelligence on. Open Describe, say or type "10 sets, open Work, exactly 1 minute of Rest between them", and capture once the outline shows. |
| 2 | A running Work Phase, readable across a room | Readable from across the room | Start Intervals and capture during Work, after the 10 s Prepare. |
| 3 | The Live Activity on the Lock Screen and in the Dynamic Island | Stays on your Lock Screen | Lock the iPhone during a Workout for the Lock Screen. For the Dynamic Island, start a Workout and switch to another app. |
| 4 | Apple Watch with heart rate and Zone | Heart rate and Zone on your wrist | A paired Watch with Heart Rate allowed in Settings, during Work. Capture on the Watch, at the Watch size. |
| 5 | Setup with Presets | Your Presets, one tap away | Save three Presets for Intervals, such as "Tabata", "Boxing 3 min" and "EMOM 10", then open the Preset menu. |

Before capturing in the Simulator, set a clean status bar:

```sh
xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl io booted screenshot shot.png
```

Screenshots must be PNG or JPEG with no transparency. The images aren't kept in the repo.
