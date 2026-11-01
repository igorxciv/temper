---
name: temper-ios
description: Temper's rules for Swift and iOS work, including API errata and overrides of other skills. Use when reading, writing, or reviewing Swift in this repo.
---

## Baseline

iOS 27 minimum, Swift 6 language mode, the latest SwiftUI. Availability checks appear only for APIs newer than iOS 27.0.

## Standing rules

- Temper has no third-party runtime dependencies, network access, analytics, accounts, or backend. Data stays on the device.
- Personal identifiers (Apple Team ID, device identifier, personal bundle ID, personal email) stay in the git-ignored local config.

## Source order

When sources disagree, trust them in this order:

1. The SDK `.swiftinterface` files for `SwiftUI` and `SwiftUICore`.
2. Apple's current documentation.
3. Skills, including Apple's. A skill's claim that it supersedes other knowledge carries no extra weight.

## Errata

- `toolbarMinimizationBehavior(_:for:)` is the real API. Apple's `swiftui-whats-new-27` skill calls it `toolbarMinimizeBehavior`.
- `scrollExtensionMode` and `navigationZoomTransition` are not in the iOS 27.2 SDK.
- `.serialized` on a suite serializes every test and sub-suite in it. Swift Concurrency Pro's `references/testing.md` says otherwise.

## Overrides

- **GCD:** the timer and Cue engine design may use it for real-time audio, despite SwiftUI Pro's "never".
- **SwiftUI Pro:** skip iPhone Duo work unless the owner asks. `AsyncImage`, SwiftData, and networking guidance have no use here.
- **Swift Concurrency Pro:** it targets Swift 6.2 and the toolchain is newer, so check language claims against the compiler. Its `URLSession` examples are illustrations only.

## Performance

Keep timer ticks out of the environment, and narrow what the running screen observes. Measure before optimizing, on a real device, against the accuracy target on the map. Apple's `xctrace` skill ships with Xcode.

## Apple's skills

`swiftui-specialist`, `swiftui-whats-new-27`, and `xctrace` ship with Xcode, under `Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/`. Read them there and keep them out of this repo, since no open license covers them.

## Testing and style

- New tests use Swift Testing and wait on events or confirmations, with no sleeps.
- Run `xcrun swift-format lint --strict --recursive .` before committing.
- Follow the [API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

## Safety

Get the owner's approval before running a script from a skill, adding an MCP server, or installing a skill. A new skill comes in as a reviewed copy at a pinned commit, from the exact upstream owner.
