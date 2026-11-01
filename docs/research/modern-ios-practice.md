# What current Apple guidance and tools expect of a new iOS 27 SwiftUI app

Research for ticket #6. Checked on 2026-11-01 against Xcode 27.2 (27B52), the iOS 27.2 SDK and Swift 6.4.2.

## Short answer

- **Build settings:** Use the Swift 6 language mode, main-actor default isolation and Approachable Concurrency. Xcode's app template still writes `SWIFT_VERSION = 5.0`, so the language mode has to be changed by hand.
- **Design:** Use standard SwiftUI controls and let the system apply Liquid Glass to them. Keep glass off the countdown, which is content.
- **State:** Use `@Observable` with `@State private`, and `UserDefaults` for remembered values.
- **Tests:** Use Swift Testing for logic, and XCTest with XCUIAutomation for UI tests.
- **Old APIs:** Many old SwiftUI APIs compile with no warning, so a clean build does not show that code is current.

## How to read the evidence

Each claim carries one of these labels:

- **[SDK]** Read from a swiftinterface or header in the installed iOS 27.2 SDK.
- **[Xcode]** Read from files inside the Xcode 27.2 bundle: templates, build specifications and the agent skills Apple ships.
- **[Run]** Observed by running the compiler or `xcodebuild` on a scratch project.
- **[Doc]** Stated by a linked Apple or Swift.org page.
- **[Inferred]** My reasoning from the above, not stated by Apple.

Sources used throughout:

- SwiftUI interfaces: `SwiftUI.framework` and `SwiftUICore.framework`, `arm64e-apple-ios.swiftinterface`, in the iOS 27.2 SDK.
- SwiftUI skill: `swiftui-specialist` and its references, in `Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources`. Its header says Apple wrote and published it.

## Toolchain

- Xcode 27 includes Swift 6.4 and the iOS 27 SDK. [Doc: [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)]
- `swift --version` reports 6.4.2, and the SDK's `DefaultDeploymentTarget` is 27.2. [Run] [SDK]
- Swift.org lists 6.4.2 as the current install. It dates the 6.4 release to September 15, 2026. [Doc: [Swift 6.4 Released](https://www.swift.org/blog/swift-6.4-released/)]
- Swift 6.4 is a compiler version, not a language mode. `-swift-version` accepts only `4`, `4.2`, `5` and `6`, and rejects `6.4` and `7`. So 6 is the newest language mode. [Run]

## Swift language mode and strict concurrency

### What the template gives you

Xcode's `Base_ProjectSettings` and `App Base` templates set these values [Xcode]:

| Setting | Template value |
| --- | --- |
| `SWIFT_VERSION` | `5.0` |
| `SWIFT_APPROACHABLE_CONCURRENCY` | `YES` |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | `MainActor` |
| `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY` | `YES` |

Apple recommends Approachable Concurrency for all projects, and main-actor isolation for modules that mainly interact with the UI. [Doc: [Embracing Swift concurrency, WWDC25](https://developer.apple.com/videos/play/wwdc2025/268/)]

### Why the language mode matters

I compiled the same unsafe code, a detached task mutating a class instance, with `swiftc` [Run]:

| Language mode and flags | Result |
| --- | --- |
| 5, no concurrency flags | No diagnostic |
| 5, main-actor isolation and the template's upcoming features | Warning: `main actor-isolated property 'x' can not be mutated from a nonisolated context` |
| 6, the same flags | The same message as an error |

Xcode's build specification says strict checking is always `complete` in Swift 6 mode and produces errors instead of warnings. [Xcode: `Swift.xcspec`]

### Moving to 6 keeps the Approachable behaviour

The `SWIFT_APPROACHABLE_CONCURRENCY` option has a build condition limiting it to language modes 4 to 5, so I checked whether it still has an effect in 6. It does. A scratch `xcodebuild` with the setting on passed these flags in Swift 6 mode [Run]:

- `-swift-version 6`
- `-default-isolation`
- `-enable-upcoming-feature NonisolatedNonsendingByDefault`
- `-enable-upcoming-feature InferIsolatedConformances`
- `-enable-upcoming-feature MemberImportVisibility`

The other Approachable features are already part of Swift 6 mode, according to the compiler's feature list. [Run: `swift -frontend -print-supported-features`]

### Consequences for the design

- Code is single-threaded on the main actor unless you opt out. Use `@concurrent` to move work off an actor. [Doc: [WWDC25 268](https://developer.apple.com/videos/play/wwdc2025/268/)]
- Under these defaults, an unannotated `nonisolated` async method runs on the main actor, which Apple's release notes call out directly. [Doc: [iOS 27 release notes, SwiftUI](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)]
- Ticket #10 should keep this in mind wherever audio or timing callbacks arrive off the main thread. [Inferred]
- `MemberImportVisibility` requires explicit imports. For example, `@Published` failed to compile until `import Combine` was added. [Run]
- The compiler lists `ExistentialAny`, `MemberImportVisibility`, `InferIsolatedConformances`, `NonisolatedNonsendingByDefault`, `InternalImportsByDefault` and `ImmutableWeakCaptures` as enabled in language mode 7. [Run] Turning on `ExistentialAny` now costs little in a new project. [Inferred]
- Swift 6.4 adds the `@diagnose` attribute for per-source warning control. [Doc: [Swift 6.4 Released](https://www.swift.org/blog/swift-6.4-released/)]

## Liquid Glass and the HIG

### Where glass belongs

- Glass is a functional layer for controls and navigation that floats above content. "Don't use Liquid Glass in the content layer." [Doc: [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)]
- Standard components pick it up automatically, and custom use should be sparing and limited to the most important functional elements. [Doc: [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)]
- Apple advises reducing custom backgrounds on controls and navigation elements such as `NavigationStack` and `toolbar(content:)`. [Doc: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)]
- The clear variant is only for components over visually rich backgrounds such as photos and video. Use regular otherwise. [Doc: [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)]
- Apply color to glass sparingly. To emphasize a primary action, color the background rather than the symbol or text, which is what prominent buttons do. [Doc: [HIG Color](https://developer.apple.com/design/human-interface-guidelines/color)]
- Avoid giving button labels a color similar to the content-layer background. [Doc: [HIG Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)]

### What changed for iOS 27

- Glass diffuses complex content more, and it gains a darkened edge and brighter specular highlights. [Doc: [Platforms State of the Union, WWDC26](https://developer.apple.com/videos/play/wwdc2026/102/)]
- A new Settings slider lets people adjust glass from ultra clear to fully tinted. Apps inherit this without code. [Doc: [WWDC26 102](https://developer.apple.com/videos/play/wwdc2026/102/)]
- Glass adapts to settings such as Reduce Transparency and Increase Contrast. [Doc: [WWDC26 102](https://developer.apple.com/videos/play/wwdc2026/102/)]
- Apple is removing the opt-out from the new design: an app recompiled with Xcode 27 uses it. [Doc: [WWDC26 102](https://developer.apple.com/videos/play/wwdc2026/102/)]
- The glass API has not visibly changed. `Glass` (`regular`, `clear`, `identity`, `tint`, `interactive`) is still marked iOS 26. `glassEffect(_:in:)`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `.buttonStyle(.glassProminent)` and `ConcentricRectangle` are all present. [SDK]

### Reading at a distance

Apple publishes no viewing-distance figure in the HIG pages I read, so the size has to be settled on a real iPhone in a gym. Ticket #9 is the natural place. What Apple does say:

- For workouts: "use large font sizes, high-contrast colors, and arrange text so that the most important information is easy to read." [Doc: [HIG Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts)]
- Also for workouts: avoid information that is not relevant, make pause and stop easy to find and tap, and give clear feedback when a session starts or stops. [Doc: [HIG Workouts](https://developer.apple.com/design/human-interface-guidelines/workouts)]
- Avoid Ultralight, Thin and Light weights. [Doc: [HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography)]
- Minimum contrast is 4.5:1 up to 17 pt, and 3:1 at 18 pt and above or in bold. [Doc: [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)]
- Do not convey information with color alone. [Doc: [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)] So a Phase needs its name on screen as well as its color. [Inferred]
- Hit regions should be at least 44x44 pt. [Doc: [HIG Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)] `.controlSize(.extraLarge)` compiles on iOS. [Run] It provides extra-large buttons for important actions. [Doc: [Build a SwiftUI app with the new design, WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/)]
- An app-specific appearance setting should be avoided, and the app should look right in both light and dark. [Doc: [HIG Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)]

### Layout

- Design for changing sizes rather than fixed devices. iOS apps now resize on iPad and Mac. [Doc: [WWDC26 102](https://developer.apple.com/videos/play/wwdc2026/102/)]
- Apple's resizability skill says iOS 27 ignores `UIRequiresFullScreen`, and it covers a foldable iPhone. [Xcode: `app-resizability`]
- HIG asks for adaptive layout even for an app locked to one orientation. [Doc: [HIG Layout](https://developer.apple.com/design/human-interface-guidelines/layout)]

### App icon

Icon Composer 2.0 ships with Xcode. It adds a sharper rendering mode and previews both the new and original design generations. [Doc: [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)]

## State management

- Use `@Observable`, not `ObservableObject`. Tracking is per property, so only the views reading a changed property update. [Xcode: `swiftui-specialist`, dataflow] [Doc: [Migrating to the Observable macro](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro)]
- `@State` is now a macro when built with Xcode 27. [SDK] [Doc: [State](https://developer.apple.com/documentation/swiftui/state)]
- Reference types stored in `@State` initialize once per view lifetime, and this back-deploys to iOS 17. [Doc: [What's new in SwiftUI, WWDC26](https://developer.apple.com/videos/play/wwdc2026/269/)]
- The lazy behaviour needs a `private` getter, so always write `@State private var`. [Xcode: `swiftui-specialist`, dataflow]
- The macro brings source breaks. Do not give a default value and also assign in `init`, and do not compose `@State` with other wrappers or macros. [Doc: [iOS 27 release notes, SwiftUI](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)]
- Make the stored property types of `@Observable` classes `Equatable`, so that setting an unchanged value does not notify. [Xcode: `swiftui-specialist`, dataflow]
- Do not send timer-driven values through the environment. Keep them in an `@Observable` model. [Xcode: `swiftui-specialist`, environment]
- `Observations`, an `AsyncSequence` over observable changes, is available from anyAppleOS 26. [SDK: Observation] Swift 6.4 adds finer-grained change notifications through SE-0506. [Doc: [Swift 6.4 Released](https://www.swift.org/blog/swift-6.4-released/)]

## Persistence for simple settings

- `@AppStorage` reads and writes `UserDefaults` and invalidates the view on change. [Doc: [AppStorage](https://developer.apple.com/documentation/swiftui/appstorage)]
- It accepts `Bool`, `Int`, `Double`, `String`, `URL`, `Date`, `Data` and `RawRepresentable` values with `Int` or `String` raw values. It has no `Codable` initializer. [SDK]
- The Dip setting fits `@AppStorage` directly. [Inferred]
- The last-used Workout, stored as a list of Phases, needs `Codable` encoded to `Data` in `UserDefaults`, behind a small store type. [Inferred]
- SwiftData is built for managed persistence and model fetching. [Doc: [SwiftData](https://developer.apple.com/documentation/swiftdata)] One remembered Workout does not need that. Multiple saved Workouts are out of scope for v1. [Inferred]
- `UserDefaults` is a required-reason API. App Store uploads must declare a reason in a privacy manifest, and `CA92.1` covers data only the app itself can access. [Doc: [Required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)] Apple states this rule for App Store Connect uploads, so an Xcode install on the owner's phone should not need it. [Inferred] Adding it is still cheap and helps anyone who later distributes a fork. [Inferred]

## Testing

- Swift Testing is the current framework for logic tests. It offers parameterized tests, traits, tags and Swift concurrency integration. [Doc: [Swift Testing](https://developer.apple.com/documentation/testing)]
- Xcode's test template has a "Testing System" option with XCTest and Swift Testing as choices, and it defaults to None. Choose Swift Testing explicitly. [Xcode]
- UI tests stay on XCTest and XCUIAutomation, because the `Testing` interface has no XCUI symbols. [SDK] [Inferred]
- XCTest gains `XCUIVoiceOverService` for driving VoiceOver and checking its focus and spoken output. [Doc: [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)] [SDK: `XCUIVoiceOverService.h`]
- The two frameworks can coexist in one file. [Doc: [Migrating from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)] A failed assertion from the other framework shows as a warning-level runtime issue, and a test plan setting controls this. [Doc: [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)]

## Performance

- Profile with the Instruments SwiftUI template. View body updates over 500 microseconds show orange, and over 1000 microseconds show red. [Doc: [Understanding and improving SwiftUI performance](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)]
- Xcode 27 adds a Swift Executors instrument covering the main actor and the cooperative pool. [Doc: [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)]
- Group custom glass in a `GlassEffectContainer` for rendering performance. [Doc: [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)]
- The countdown should update its view no faster than the digits change, and only the view reading the value should update. [Inferred from the Observation and environment guidance above]
- `Text(timerInterval:pauseTime:countsDown:showsHours:)` and `TimelineView` both exist as options for ticket #10 to weigh. [SDK] I did not test either against the accuracy target.
- `EnvironmentValues.systemPrefersReducedResourceUsage` is new in anyAppleOS 27. [SDK] I found no description of its behaviour.

## Accessibility

- Offer enlargement of at least 200 percent where possible, through Dynamic Type or custom UI. [Doc: [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)]
- Text styles give Dynamic Type automatically, and layouts should adapt at all sizes with little truncation. [Doc: [HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography)]
- Motion should be optional and never the only way to communicate. Respond to Reduce Motion. [Doc: [HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)]
- The relevant environment values all exist: `accessibilityReduceMotion`, `accessibilityReduceTransparency`, `accessibilityDifferentiateWithoutColor`, `accessibilityShowButtonShapes` and `colorSchemeContrast`. So do `AccessibilityTraits.updatesFrequently` and `.accessibilityValue`. [SDK]
- Test custom elements with different display and accessibility settings, including the glass preference. [Doc: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)]
- Accessibility Inspector ships with Xcode. [Xcode]
- How spoken Cues and VoiceOver share the audio is not settled by anything here. Tickets #4 and #11 should cover it. [Inferred]

## Keeping the screen awake

SwiftUI has no modifier for this. `UIApplication.isIdleTimerDisabled` is still the API. [SDK] Apple says to set it only if necessary and reset it to false when the need ends. [Doc: [isIdleTimerDisabled](https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled)] So it should be on only while a Workout runs. [Inferred]

## Recommendations

These are my conclusions from the evidence above, not Apple's prescriptions for this app.

### Project setup

1. Start from Xcode's iOS App template, then change `SWIFT_VERSION` to `6.0`. Leave `SWIFT_APPROACHABLE_CONCURRENCY = YES`, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and member import visibility as the template sets them.
2. Enable the `ExistentialAny` upcoming feature.
3. Set the deployment target to iOS 27.0, unless the owner's device justifies a later point release.
4. Choose Swift Testing as the test system. Add a UI test target with XCUIAutomation only for flows that need it.
5. Add `PrivacyInfo.xcprivacy` declaring `CA92.1` for `UserDefaults`, and no other data use.

### Design

6. Build the setup and Settings screens from `NavigationStack`, `Form` or `List`, and standard controls, with no custom bar or control backgrounds.
7. On the running screen, show the countdown and Phase name as plain content with no glass behind them. Use a solid high-contrast background.
8. Make Pause and Resume `.buttonStyle(.glassProminent)` and Stop `.buttonStyle(.glass)`, both at `.controlSize(.extraLarge)`. Wrap them in a `GlassEffectContainer` only if they are custom glass views. Use regular glass, never clear.
9. Set the countdown in a bold or semibold system font with `.monospacedDigit()`, sized from the available space rather than from Dynamic Type, with a `minimumScaleFactor`. Use text styles for everything else. This sizing rule is my judgement, because a countdown that already fills the screen cannot grow further.
10. Show the Phase name in text as well as color. Check contrast in light and dark, and with Increase Contrast and Reduce Transparency on. Move the glass slider to both ends to test it.
11. Do not add an in-app appearance setting. Whether the running screen forces a dark look is a decision for ticket #11, and it should be weighed against the HIG's advice on honoring the system setting.
12. Gate any digit animation such as `.contentTransition(.numericText(countsDown: true))` behind Reduce Motion. Consider dropping it altogether if it hurts reading at a distance.
13. Avoid fixed device sizes or orientation assumptions. Use a layered Icon Composer icon.

### Code

14. Hold one `@Observable` Workout model in `@State private var`. Give its stored properties `Equatable` types. Keep timing values out of the environment.
15. Use `@AppStorage` for Dip, and a small `Codable` store over `UserDefaults` for the last-used Workout. Do not use SwiftData in v1.
16. Keep Phase sequencing logic in plain value types so that Swift Testing can cover it without a UI. Annotate the off-main work with `@concurrent` or `nonisolated`, as ticket #10 decides.
17. Set `isIdleTimerDisabled` on Workout start, and clear it on every way out of a Workout.
18. Search new code for the APIs listed below during review, because the compiler will not flag most of them.

## Outdated patterns to avoid

Apple calls these "soft deprecated": they carry `deprecated: 100000.0` in the SDK, which suppresses compiler warnings. [Xcode: `swiftui-specialist`, soft-deprecation] I confirmed that `NavigationView`, `foregroundColor`, `cornerRadius` and `navigationBarTitle` built with no warning for an iOS 27 target. [Run] Apple's full list is `swiftui-specialist-ref-soft-deprecated-apis.md.packaged` in the Xcode bundle. Ticket #7 may want it.

| Avoid | Use | Status |
| --- | --- | --- |
| `NavigationView` and its styles | `NavigationStack` or `NavigationSplitView` | Soft deprecated [SDK] |
| `navigationBarTitle`, `navigationBarItems`, `navigationBarHidden` | `navigationTitle`, `toolbar`, `toolbar(.hidden)` | Soft deprecated [SDK] |
| `foregroundColor` | `foregroundStyle` | Soft deprecated [SDK] |
| `accentColor(_:)` | Asset catalog accent color or `tint` | Soft deprecated [SDK] |
| `cornerRadius` | `clipShape`, or a concentric shape | Soft deprecated [SDK] |
| `edgesIgnoringSafeArea` | `ignoresSafeArea` | Soft deprecated [SDK] |
| `Alert`, `ActionSheet`, `.actionSheet` | `alert` and `confirmationDialog` with `actions:` | Soft deprecated [SDK] [Xcode] |
| `.tabItem` | `Tab` | Soft deprecated [SDK] |
| `.autocapitalization` | `textInputAutocapitalization` | Soft deprecated [SDK] |
| `.squareBorder` and `.roundedBorder` text field styles | `.bordered` | Soft deprecated [Doc: [iOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)] |
| `onChange(of:perform:)` | Zero- or two-parameter `onChange` | Hard deprecated in iOS 17; the compiler warns [SDK] [Run] |
| `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject` | `@Observable`, `@State`, `@Environment` | Not marked deprecated in the SDK, but Apple's guidance says not to use them for new models [SDK] [Xcode] |
| `init` assigning to a `@State` that also has a default value | Leave out the default | Compile error under the macro [Doc: [iOS 27 release notes](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)] |
| `UIDesignRequiresCompatibility` | Nothing; adopt the new design | Opt-out being removed [Doc: [WWDC26 102](https://developer.apple.com/videos/play/wwdc2026/102/)] |
| `UIRequiresFullScreen` | A layout that resizes | Ignored in iOS 27 [Xcode: `app-resizability`] |
| Custom backgrounds on bars and controls | The system appearance | Discouraged [Doc: [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)] |
| `.glassEffect` on content, or clear glass over plain backgrounds | Standard materials in content; regular glass | Against the HIG [Doc: [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)] |
| `Timer.publish` state passed through the environment | An `@Observable` model | Named as an anti-pattern [Xcode: `swiftui-specialist`, environment] |
| Swift 5 language mode in new code | Swift 6 | Data races stay warnings [Run] |

## Not verified, and conflicts between sources

- **Nothing was seen on a device.** I compiled code but did not render it. Legibility at a distance, glass over a Phase color and `.extraLarge` sizing all still need checking on a real iPhone.
- **No iOS height for `.extraLarge`.** The HIG Buttons table that gives 64 pt for extra large is under visionOS. I found no iOS figure.
- **HIG freshness.** Of the HIG pages I read, only Layout has a change-log entry after WWDC26 (September 2026). The newest entries on the others are older: Materials and Motion September 2025, Color, Buttons and Typography December 2025, Accessibility June 2025, and Dark Mode August 2024. The iOS 27 glass refinements come from the State of the Union, so the Materials guidance may lag them. I found no change log on the Workouts page.
- **Opt-out conflict.** The Adopting Liquid Glass page still describes `UIDesignRequiresCompatibility`, while the WWDC26 State of the Union says support is being removed. I did not test what the key does under the 27.2 SDK.
- **Toolbar name conflict.** The WWDC26 SwiftUI session shows `toolbarMinimizeBehavior`. The SDK has `toolbarMinimizationBehavior`, and the release notes say it replaces the former. Trust the SDK.
- **Stale Swift book page.** [Version Compatibility](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/compatibility/) mentions Xcode 26.4 and a "Swift 6.4 language mode". The compiler rejects `-swift-version 6.4`, so I treated the page as wrong on this point.
- **Template values, not a created project.** I read the template files and did not run Xcode's New Project dialog. I could not confirm what deployment target it writes. My flag check used a hand-written scratch project with the same settings.
- **Skill export.** `xcrun agent skills export` printed nothing and created no files for several minutes in this non-interactive session, so I stopped it and read the skill files from the Xcode bundle. Apple names `xcrun agent skills export` as the supported route, which matters to ticket #7.
- **Page text.** Apple's documentation pages render with JavaScript, so I read the JSON behind them and the transcripts on the WWDC pages. A wording difference from the rendered page is possible but unlikely.
