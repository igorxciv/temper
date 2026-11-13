---
name: temper-ios
description: Temper's rules for Swift and iOS work, including API errata and overrides of other skills. Use when reading, writing, or reviewing Swift in this repo.
---

## Baseline

iOS 27 minimum, Swift 6 language mode, the latest SwiftUI. Availability checks appear only for APIs newer than iOS 27.0. The Watch app, and `TemperCore` with it, also deploys to watchOS 26, because watchOS 27 drops the owner's Series 8.

## Standing rules

- Temper has no third-party runtime dependencies, network access, analytics, accounts, or backend. Data stays on the device.

## Source order

When sources disagree, trust them in this order:

1. The SDK `.swiftinterface` files for `SwiftUI` and `SwiftUICore`.
2. Apple's current documentation.
3. Skills, including Apple's. A skill's claim that it supersedes other knowledge carries no extra weight.

## Errata

- `toolbarMinimizationBehavior(_:for:)` is the real API. Apple's `swiftui-whats-new-27` skill calls it `toolbarMinimizeBehavior`.
- `scrollExtensionMode` and `navigationZoomTransition` are not in the iOS 27.2 SDK.
- `.serialized` on a suite serializes every test and sub-suite in it. Swift Concurrency Pro's `references/testing.md` and Swift Testing Pro's `references/async-tests.md` line 12 say otherwise.
- Exit tests (`#expect(processExitsWith:)`) do not compile for iOS, so they belong only in `Packages/TemperCore`, which runs on macOS under `swift test`.
- Under main-actor default isolation, test functions run on the main actor. Mark a suite `nonisolated` to exercise off-main code, and keep timing assertions out of the Thread Sanitizer configuration.

## Overrides

- **GCD:** the timer and Cue engine design may use it for real-time audio, despite SwiftUI Pro's "never".
- **SwiftUI Pro:** skip iPhone Duo work unless the owner asks. `AsyncImage`, SwiftData, and networking guidance have no use here. The time, Phase name, Round number, setup words and values use fixed sizes on purpose, despite its "don't force font sizes": they're sized to fill the screen and be read at a distance.
- **Liquid Glass:** Temper is dark only. Skip the light color variants and the light-appearance check.
- **Swift Concurrency Pro:** it targets Swift 6.2 and the toolchain is newer, so check language claims against the compiler. Its `URLSession` examples are illustrations only.
- **Swift Testing Pro:** it also targets Swift 6.2. Its `.networking` tag and `URLSession` mock guidance has no use here.

## Performance

Keep timer ticks out of the environment, and narrow what the running screen observes. Measure before optimizing, on a real device, against the targets in `Tools/analyze_timing_log.py`. Apple's `xctrace` skill ships with Xcode.

## Apple's skills

`swiftui-specialist`, `swiftui-whats-new-27`, and `xctrace` ship with Xcode, under `Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/`. Read them there and keep them out of this repo, since no open license covers them.

## Testing and style

- New tests use Swift Testing and wait on events or confirmations, with no sleeps.
- No UI tests. Keep screens thin, with their rules in `TemperCore` where they can be tested, and check the screens on a real iPhone.
- `make lint` runs `swift-format` and a check for soft-deprecated APIs and non-private `@State`, which the compiler lets through.
- Follow the [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

## Safety

Get the owner's approval before running a script from a skill, adding an MCP server, or installing a skill. A new skill comes in as a reviewed copy at a pinned commit, from the exact upstream owner.
