# What strong iOS developers actually use, and what Temper should take from it

Checked on 2026-11-01 against Xcode 27.2 (27B52), the iOS 27.2 SDK and Swift 6.4.2. This note builds on `modern-ios-practice.md`, `ios-skills.md` and `free-signing.md` and does not repeat them. It only recommends.

## Answer

Temper can get almost everything it needs from what ships with Xcode. Take a plain `.xcodeproj` with buildable folders, one local package for the timing logic, `swift-format` with six extra rules, a `grep` for old APIs, a test plan with a Thread Sanitizer configuration, a Makefile, a tracked pre-commit hook, a short `AGENTS.md`, and one GitHub Actions workflow pinned by SHA. Add one skill, Swift Testing Pro, with a few errata.

Skip every third-party dev tool for now: SwiftLint, SwiftFormat, XcodeGen, Tuist, Periphery, xcbeautify, mise, fastlane, snapshot libraries and MCP servers. Once they are gone, mise has nothing left to pin. Skipping SwiftLint is the one call that goes against most of the apps I read, so I explain it below and give a fallback config.

Three findings change the earlier picture:

- Periphery's open-source repo was archived on 2026-08-12 and the tool is going commercial. [Repo peripheryapp/periphery@56a0eb6 README.md]
- XcodeBuildMCP was renamed MobileBuildMCP in September, so old names and old install commands are stale. [Repo getsentry/MobileBuildMCP@2998ac7 release v2.7.1]
- Apple says Undefined Behavior Sanitizer does not cover Swift, and Thread Sanitizer cannot run on a device. [Doc: [Diagnosing memory, thread, and crash issues early](https://developer.apple.com/documentation/xcode/diagnosing-memory-thread-and-crash-issues-early)]

What people's repos contain is often less tidy than the advice around them. None of the eight apps turned on a sanitizer in any file I could find, only Firefox pins its GitHub Actions by SHA, and seven of the eight commit a Team ID to `project.pbxproj`. Temper should not copy those three habits.

## Corrections after review

Applying this note found these problems. The adopted files are in [PR #15](https://github.com/igorxciv/temper/pull/15), and the sections below are corrected or marked.

- **`.swift-format`:** a partial `rules` map replaces the defaults instead of adding to them. The six-rule config first written here turned off most default rules, including naming, semicolons and block comments. List all 43 rules. [Run]
- **False-positive check:** the first run of "Clean, no false positives" below used that weakened config. A clean SwiftUI and Swift Testing sample was re-run under all 37 enabled rules and passed. [Run]
- **`make identifiers`:** every pattern now has a test against a real violation through `git grep`. PR #15 also checks for a Team ID in a tracked `.xcconfig` and for home paths in any tracked file. [Run]
- **`make lint`:** skips `Prototypes/`, since prototypes are throwaway and the current one gives 103 lines of findings. The trailing-space `@State` pattern became `@State (var|let)\b`, which an editor cannot silently break. [Run]
- **`AGENTS.md`:** the PR's version lists only what exists today. The version below is the target for when the app exists.

## How this was checked

Labels: **[Repo owner/name@sha path]** is a file I read at that commit. **[Doc]** is official documentation. **[Author: link]** is the person's own post. **[Run]** is something I ran on this Mac in scratch space. **[Inferred]** is my reasoning.

I read repos through the GitHub REST API at a pinned commit (path listings and individual raw files) rather than cloning them. The worktree guard on this session refuses `git` commands aimed outside the worktree, and the API needs no clone, hooks or submodules. Nothing from a repo was run. Text in those repos addressed to agents was treated as data. Scratch projects were my own, with fake identifiers.

### Repos read

"Last activity" is the date of the newest commit on the default branch.

| Repo | Commit | Last activity | Stars | Read |
|---|---|---|---|---|
| Dimillian/IceCubesApp | `98098b9` | 2026-10-13 | 7,100 | In full: `.swiftformat`, `CLAUDE.md`, dependabot, its one workflow. In part: pbxproj settings, one package manifest. |
| Ranchero-Software/NetNewsWire | `70c5dce` | 2026-10-25 | 10,494 | In full: `.swiftlint.yml`, `CLAUDE.md`, `ci.yml`, iOS test plan, no-signing xcconfig, `fail_on_warnings.sh`, `setup.sh`. |
| signalapp/Signal-iOS | `b6beaf0` | 2026-10-29 | 12,306 | In full: `.swiftformat`, `.swiftlint.yml`, `.xcode-version`, Makefile, `build-and-test.sh`. In part: `main.yml`, `precommit.py`. |
| wikimedia/wikipedia-ios | `09fa0f3` | 2026-10-30 | 3,472 | In full: strict concurrency workflow. In part: `CLAUDE.md`, `AGENTS.md`, `.swiftlint.yml`, unit test workflow, test plans. |
| mozilla-mobile/firefox-ios | `167e2d2` | 2026-10-30 | 13,068 | In full: `AGENTS.md`, `CLAUDE.md`, `.swiftlint.yml`, `.periphery.yml`. In part: test plans. |
| duckduckgo/apple-browsers | `f1d5744` | 2026-10-31 | 270 | In full: `AGENTS.md`, `Mintfile`. In part: `.swiftlint.yml`, iOS PR workflow, dependabot, actionlint workflow. This replaced the archived `duckduckgo/iOS`. |
| mastodon/mastodon-ios | `6d45b16` | 2026-10-29 | 2,283 | In part: build workflow, test plans, pbxproj settings. |
| pointfreeco/isowords | `c727d3a` | 2024-08-16 | 3,006 | In part: Makefile, workflows, root `Package.swift`. |
| steipete/CodexBar | `897bff3` | 2026-10-31 | 22,933 | In full: `.swiftformat`, `.swiftlint.yml`. In part: `AGENTS.md`, Makefile, `ci.yml`. A macOS app. |
| steipete/RepoBar | `06b451e` | 2026-10-20 | 2,222 | In full: `AGENTS.md`, `RepoBariOS/project.yml`. |
| steipete/agent-rules | `42993e4` | 2026-04-27 | 5,672 | README. Archived. |
| steipete/agent-scripts | `d210c0a` | 2026-10-30 | 7,431 | Path list only. |
| twostraws/Swift-Testing-Agent-Skill | `2d6bba1` | 2026-05-17 | 472 | In full: all skill files, plus a scan. |
| AvdLee/Swift-Testing-Agent-Skill | `798e9b1` | 2026-04-22 | 478 | In part: start of `SKILL.md`, parallelization reference. |
| airbnb/swift | `341e154` | 2026-10-29 | 2,761 | In part: README start, `airbnb.swiftformat`, `swiftlint.yml`. |
| getsentry/MobileBuildMCP | `2998ac7` | 2026-10-22 | 6,532 | In part: README, `.mcp.json`, hook, one code search, privacy doc. |
| peripheryapp/periphery | `56a0eb6` | 2026-08-12 | 6,181 | README notice, `.mise.toml`. Archived. |
| swiftlang/swift-format | `77e88e4` | 2026-10-28 | 2,966 | In part: rule documentation. |
| nicklockwood/SwiftFormat | `048f2e4` | 2026-10-31 | 8,950 | In part: README FAQ. |
| yonaskolb/XcodeGen | `783a19e` | 2026-10-13 | 8,915 | In part: changelog, spec search. |
| cpisciotta/xcbeautify | `513e4b1` | 2026-08-10 | 1,553 | In part: README, open issues. |
| actions/runner-images | `4da2307` | 2026-10-30 | 13,554 | In part: `xcode-27-arm64-Readme.md`, macOS 26 readme, issues 14404, 15000, 15199. |

## Who counts, and why

I judged people by what can be checked. These follower counts are from the GitHub API today, and stars are in the table above.

| Person or org | Reason to count them | Verdict |
|---|---|---|
| Peter Steinberger (steipete) | 53,484 followers, ships Swift apps with public config | Keep, for agent files and tool config. His apps are mostly macOS. |
| Paul Hudson (twostraws) | 9,990 followers, author of the skills Temper already uses | Keep, for skills. I read no app config of his. |
| Thomas Ricouard (Dimillian) | 4,388 followers, Ice Cubes is a modern SwiftUI app with Swift 6 settings | Keep. The closest match to Temper's settings. |
| Antoine van der Lee (AvdLee) | 3,242 followers, runs SwiftLee, sells RocketSim | Keep, for posts with measurements. RocketSim is closed source, so I read no app config, and he discloses his interest. [Author: [Xcode MCP costs](https://www.avanderlee.com/ai-development/xcode-mcp-simulator-token-costs/)] |
| Ranchero Software (NetNewsWire) | Long-lived shipping app, 10,494 stars, no signing values in its project | Keep. The best signing model of the eight. |
| Point-Free | Authors of swift-snapshot-testing (4,388 stars) | Keep for tools. isowords is stale: its CI selects Xcode 15.3. [Repo pointfreeco/isowords@c727d3a .github/workflows/ci.yml] |
| Donny Wals | 340 GitHub followers, but publishes first-hand tool reports | Keep as a witness on friction only. |
| Majid (mecid) | 2,111 followers, blog | Keep as a witness on Xcode setup only. |
| Matt Massicotte | 862 followers, concurrency writing | Dropped for tooling. One site search found no lint or CI post. |
| Natalia Panferova | 243 followers, former SwiftUI team per her bio | Dropped for tooling. No public config found. |
| John Sundell, Krzysztof Zabłocki | 7,495 and 4,881 followers | Dropped. I did not read current config from either, and their well-known repos (Inject, Sourcery) do not bear on this question. |

Large apps are ground truth for what survives contact with a team, not for what a one-person timer needs. Signal, Firefox and DuckDuckGo have release trains, translators and hundreds of targets. Where a practice exists for that reason I say so.

## Who uses what

"none" means I checked the file list or config and did not find it. A blank cell means I did not check. Code search covers the default branch only, so "none" for sanitizers and MCP is good evidence and not proof.

### Apps

| Project | Formatter | Linter | Project file | Local packages | Swift mode in pbxproj | Team ID in pbxproj |
|---|---|---|---|---|---|---|
| Ice Cubes | SwiftFormat, one line (`--indent 2`) | none | xcodeproj, buildable folders | 13 manifests | 6.0, MainActor default | Yes, 4 lines |
| NetNewsWire | none (`.editorconfig`, tabs) | SwiftLint, `brew install`, unpinned | xcodeproj, buildable folders | 17 | Set in 22 xcconfig files | No |
| Signal | SwiftFormat, explicit rules | SwiftLint, `Signal/` only | xcodeproj, CocoaPods, no buildable folders | 4 | 5.0 | Yes, 4 lines |
| Wikipedia | none | SwiftLint | xcodeproj, some buildable folders | 4 | 5.0 | Yes, 89 lines |
| Firefox | none | SwiftLint, 97 listed rules with many commented out, `.swiftlint-version` | xcodeproj, buildable folders | 4 | 6.0, strict concurrency varies by target | Yes, 51 lines |
| DuckDuckGo | none | SwiftLint 0.63.0 through Mint | xcodeproj, buildable folders | 70 | 5.0 | Yes, 14 lines |
| Mastodon | none | none | xcodeproj, buildable folders | 1 | 5.0 | Yes, 32 lines |
| isowords | `swift format` from the toolchain | none | xcodeproj over a root package | 4 | 5.0 | Yes, 33 lines |
| CodexBar | SwiftFormat | SwiftLint with analyzer rules | SwiftPM, `project.yml` for one widget | | | |
| RepoBar | SwiftFormat | SwiftLint | SwiftPM, XcodeGen for iOS | shared `RepoBarCore` | 6.2 | Yes, in `project.yml` |

[Repo: the commits above; `.swiftformat`, `.swiftlint.yml`, `Mintfile`, `project.pbxproj` and path lists]

### Agents, CI and tests

| Project | Agent file | Skills in repo | MCP named | CI host and label | Log filter | Sanitizer in plan or scheme | Dead code | Hook |
|---|---|---|---|---|---|---|---|---|
| Ice Cubes | Long `CLAUDE.md` | none | XcodeBuildMCP | `macOS-latest`, translations only | | none | none | none |
| NetNewsWire | Short `CLAUDE.md` | none | none | `macos-26`, Xcode 26.6 | xcbeautify | none | none | none |
| Signal | none | none | none | `xcode-27-xlarge`, Xcode 27.1 | xcbeautify | none | none | Copied by hand into `.git/hooks` |
| Wikipedia | `AGENTS.md` and `CLAUDE.md`, architecture guide | 3 | none | `xcode-27`, Xcode 27.1 | | none | none | |
| Firefox | `AGENTS.md`, `CLAUDE.md` is `@AGENTS.md` | 3 | none | Bitrise, Taskcluster, some Actions | | none | Periphery config and scheme | `.githooks/pre-push` |
| DuckDuckGo | Short `AGENTS.md` and `CLAUDE.md` | 9 | none | Self-hosted, `image:osx-tahoe-27` | xcbeautify | none | none | |
| Mastodon | none | none | none | `macos-15`, Xcode 26.2 via fastlane | | none | none | |
| isowords | none | none | none | `macos-14`, Xcode 15.3 | | none | none | |
| CodexBar | Long `AGENTS.md` | Yes, `.agents/skills` | none | | | | SwiftLint `unused_declaration` | |
| RepoBar | `AGENTS.md` | | none | | | | | |

Testing frameworks: Ice Cubes, NetNewsWire, Signal, DuckDuckGo, Wikipedia and Firefox all have Swift Testing files, usually beside older XCTest. [Run: `gh search code "import Testing"`] Snapshot libraries appeared in DuckDuckGo and isowords only among those searched. [Run: code search; Repo pointfreeco/isowords@c727d3a Package.swift]

### People, from their own words

| Person | Says | Repos show |
|---|---|---|
| Steinberger | "Almost all MCPs really should be clis." [Author: [Just Talk To It](https://steipete.me/posts/just-talk-to-it), date not shown, about October 2025] | No MCP in CodexBar or RepoBar config. Matches. |
| Steinberger | "no hook will stop them", and also suggests a git hook to block commits [same post] | `hooks/pre-commit` in `agent-scripts`. He uses hooks and does not trust them alone. |
| Steinberger | Agent file of about 800 lines, "organizational scar tissue" [same post] | CodexBar `AGENTS.md` is long and full of incident-specific rules. Matches. |
| van der Lee | Keep the root file as an index. Cut two files from about 8 KB to about 1.4 KB. [Author: [Reduce token usage](https://www.avanderlee.com/ai-development/reduce-token-usage-claude-code-codex-cursor/), 2026-09-28] | 751 of 2,141 RocketSim builds ran raw although `AGENTS.md` asked for a filter, so he moved to a hook. His own numbers. |
| van der Lee | "I configured SwiftLint and fixed all issues." [Author: [AI app development](https://www.avanderlee.com/ai-development/ai-app-development-what-i-learned-in-one-month/), 2026-01-26] | I could not read RocketSim's config. |
| Hudson | LLMs writing SwiftUI "_also_ adopted many of the same anti-patterns", so the skill gives deprecated API, performance and accessibility advice. [Author: [SwiftUI agent skill](https://www.hackingwithswift.com/articles/282/swiftui-agent-skill-claude-codex-ai), 2026-03-11] | His repos are Markdown only, no scripts. [`ios-skills.md`, and scan below] |
| Wals | Forbids raw `xcodebuild` in his agent file and uses FlowDeck. Picks XcodeBuildMCP as the free option. Approves Xcode's agent prompt daily. [Author: [FlowDeck post](https://www.donnywals.com/how-i-use-flowdeck-to-let-my-ai-agent-build-and-run-my-apps/), 2026-04-17] | No repo checked. |
| Majid | Xcode's agent support with a symlinked skills folder, AvdLee's skills. [Author: [Agentic coding in Xcode](https://swiftwithmajid.com/2026/02/10/agentic-coding-in-xcode/), 2026-02-10] | No repo checked. |
| Ricouard | "**No ViewModels**" [Repo Dimillian/IceCubesApp@98098b9 CLAUDE.md] | The same file calls older ViewModels legacy. It asks agents to build after every edit, but the repo has no build CI. Its `CLAUDE.md` also holds the author's absolute home path, which Temper must not do. |

DuckDuckGo states the best rule for an agent file: "Add a line only when agents demonstrably get something wrong and nothing catches it during the task." [Repo duckduckgo/apple-browsers@f1d5744 AGENTS.md]

## Findings by area

### Project generation

All eight apps commit an `.xcodeproj`, and six use buildable folders (Signal and isowords do not). None uses Tuist. XcodeGen appears only in steipete's iOS and widget side projects. [Table above]

- Buildable folders record only the folder path, not each file. [Doc: [Xcode 16 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-16-release-notes)] I added new files to a scratch folder and the target compiled them with no project edit. [Run] That removes most of what generators were for, and lets agents add files safely.
- XcodeGen has one real attraction for Temper: if `.xcodeproj` were generated and ignored, the Team picker could not leak into a tracked file. [Inferred] It is outweighed. A clone could not open in Xcode until a tool is installed, the owner wants to install from Xcode, and XcodeGen lags new Xcode. Its `xcode27_0` format and its fix for a failed "Xcode 27.2 project conversion" are still under "Next Version", after release 2.46.0. [Repo yonaskolb/XcodeGen@783a19e CHANGELOG.md]
- Tuist solves large-project problems: its docs talk of "unreliable incremental builds and fragile project configurations" as Xcode projects grow. [Doc: [Tuist projects](https://tuist.dev/en/docs/guides/features/projects)] Temper has one app target. [Inferred]

### Layering xcconfig

NetNewsWire is the model: no Team ID in its project, 22 xcconfig files, and a `setup.sh` that writes personal values into `../SharedXcodeSettings`, outside the repo. [Repo Ranchero-Software/NetNewsWire@70c5dce setup.sh, xcconfig/] The 22 files exist for many targets on two platforms. Temper needs one tracked file and the ignored local one from `free-signing.md`. Of the eight, seven commit Team IDs to the project, so this is the one layout worth copying. A single rule gives each target its own bundle ID without touching the project file. [Run: `$(BUNDLE_ID_PREFIX).$(TARGET_NAME:lower)` gave `org.example.temper` and `org.example.tempertests`, with zero matches for the signing guard in the pbxproj]

### Local package

Ice Cubes, NetNewsWire, Wikipedia, Firefox and DuckDuckGo all split code into local packages, and RepoBar keeps its logic in `RepoBarCore` so it can run under `swift test`. [Repo: manifests above] The numbers mostly reflect team size. Temper needs one package. [Inferred]

What I measured on a package and a hosted test target of three small tests:

| Run | Time |
|---|---|
| `swift test`, cold | 12.3 s [Run] |
| `swift test`, warm | 1.5 s [Run] |
| `xcodebuild test`, first run, two configurations, clones | 48.7 s [Run] |
| `xcodebuild test`, warm, simulator shut down, with clones | 35.4 s [Run] |
| `xcodebuild test`, warm, simulator booted, no clones | 5.0 s, 24.4 s the first time after boot [Run] |

Speed alone is a modest gain against a booted simulator. These count for more:

- Hosted tests launch the app, so they would launch Temper's audio setup. [Inferred]
- The package cannot reach UIKit or the screen, which keeps the Phase and timing logic clean for later training features. [Inferred]
- No simulator is involved. Simulator daemons were crashing during my runs. [Run: crash reports from `siriactionsd`, `chronod` and others during testing]

Costs, each checked:

- `.iOS(.v27)` and `.macOS(.v27)` need `swift-tools-version: 6.4`. A 6.2 manifest fails with "'v27' is unavailable". [Run]
- `swift test` runs on macOS, and `AVAudioSession` "is unavailable in macOS". [Run] So audio stays in the app target. The Cue scheduling logic can stay in the package only if it does not import AVFAudio types that need the session. [Inferred, for #10]
- Package settings are separate from xcconfig, so they are written twice. [Repo Dimillian/IceCubesApp@98098b9 Packages/Timeline/Package.swift does the same]
- Under `.defaultIsolation(MainActor.self)`, test functions run on the main actor. `MainActor.preconditionIsolated()` passed inside a plain `@Test`, and a helper class needed `nonisolated` to be touched from a task group. [Run] So parallel execution means little until a suite is marked `nonisolated`. Off-main engine tests should be.

### Formatters and linters

`swift-format` and SwiftFormat overlap. SwiftLint complements either one: "SwiftLint is primarily designed to find and report code smells... SwiftFormat is designed to fix them." [Repo nicklockwood/SwiftFormat@048f2e4 README.md]

**Experts disagree on the formatter.** Airbnb, Signal, Ice Cubes and steipete use SwiftFormat. Airbnb's reason is that "Most rules should be autocorrectable". [Repo airbnb/swift@341e154 README.md] Point-Free runs the toolchain's `swift format`. [Repo pointfreeco/isowords@c727d3a Makefile] For Temper I pick `swift-format`: `xcrun` already finds it, it versions with Xcode, and it needs no install, no pin and no CI step to fetch it. SwiftFormat's larger rule set is worth most when many people touch a codebase. [Inferred]

Rules I tested on sample SwiftUI and Swift Testing code with `swift-format` 6.4.4 [Run]:

- Clean, no false positives: `Button { } label: { }`, `ForEach`, raw-identifier test names, `snake_case` under `@Test`.
- `NeverForceUnwrap` and `NeverUseForceTry` do not fire in a file that imports `Testing`, including its helpers. The docs state this too. [Repo swiftlang/swift-format@77e88e4 Documentation/RuleDocumentation.md]
- Noisy: `UseEarlyExits` flagged a normal `if let ... else` return, and reported it twice. `UseWhereClausesInForLoops` and `NoLeadingUnderscores` give style opinions with no safety value. Leave these off.
- It does not catch `@State var`, or `foregroundColor`. Those need a separate check.

**SwiftLint is the unpopular skip.** Five of the eight apps run it, and so do CodexBar, RepoBar and Airbnb's guide. Ice Cubes, Mastodon and isowords do not. [Table above] Config sizes vary a lot: Firefox lists 97 rules with many commented out, Airbnb enables 11, and NetNewsWire keeps the defaults and disables 15. [Repo mozilla-mobile/firefox-ios@167e2d2 .swiftlint.yml; airbnb/swift@341e154 swiftlint.yml; Ranchero-Software/NetNewsWire@70c5dce .swiftlint.yml]

The rules that would help Temper are few, and I found three things a grep cannot do: `accessibility_label_for_image`, `accessibility_trait_for_button`, and comment-aware matching. The two rules that matter most are `@State` privacy, needed for the lazy macro behaviour described in `modern-ios-practice.md`, and soft-deprecated names, which compile silently. Both fit in a one-line `grep` that I ran and that caught both samples. [Run] Adding SwiftLint means a downloaded binary, a version to keep current, and a tool I could not test here against Swift 6.4 raw identifiers. So skip it, and reconsider if any of these happen:

- The grep list passes about 25 names.
- Comments start triggering false matches.
- The owner wants the accessibility rules once screens exist.

If that happens, this is the fallback, pinned with mise at `swiftlint = "0.65.1"` [Repo realm/SwiftLint release 0.65.1, 2026-08-21]. I confirmed `PrivateSwiftUIStatePropertyRule` exists in its source and that Firefox lists the two accessibility rules. I did not run it.

```yaml
only_rules:
  - private_swiftui_state
  - accessibility_label_for_image
  - accessibility_trait_for_button
  - unused_optional_binding
  - unowned_variable_capture
  - superfluous_disable_command
  - invalid_swiftlint_command
```

### Test plans and sanitizers

No plan, scheme or workflow in the eight apps enables a sanitizer. [Run: code search for `threadSanitizerEnabled`, `enableThreadSanitizer`, `enableAddressSanitizer`, `undefinedBehaviorSanitizerEnabled`; plus every test plan in the NetNewsWire, Wikipedia, Firefox and Mastodon listings and the first 14 in DuckDuckGo] Those apps mostly avoid real-time threads. Temper's engine runs audio callbacks off the main thread, and those callbacks are exactly what the compiler's checks stop seeing once someone writes `@unchecked Sendable` or `nonisolated(unsafe)`. So here I go against common practice for a specific reason. [Inferred]

What each option does for Temper:

| Option | Fact | Decision |
|---|---|---|
| Thread Sanitizer | Simulator and macOS only, 2x to 20x slowdown, 5x to 10x memory. [Doc] Caught an `@unchecked Sendable` race that passed without it, in `swift test` and on the Simulator; the Address configuration passed the same test. [Run] | Adopt, as a second plan configuration. Timing assertions must not run in it. [Inferred] |
| Address Sanitizer | Memory corruption, 2x to 3x memory. [Doc] `swift test --sanitize=address` passed. On one Simulator device the runner crashed at launch on four consecutive commands, with `mach_vm_allocate_kernel failed` in one crash report I read, and it passed on a clone of that device and on another device. [Run] | Skip until #10 touches `UnsafePointer` buffers. Then add it. |
| Undefined Behavior Sanitizer | "supports only C-based languages". [Doc] | Skip. |
| Main Thread Checker | No plan I read sets it, so all use Xcode's default. [Repo: plans above] | Leave unset. |
| `parallelizable` | Setting it true cloned the Simulator: 35 s against 5 s. [Run] Swift Testing runs tests in parallel by default. [Repo twostraws/Swift-Testing-Agent-Skill@2d6bba1 references/core-rules.md; AvdLee/Swift-Testing-Agent-Skill@798e9b1 references/parallelization-and-isolation.md] | Leave off. |
| `testExecutionOrdering: random`, `testTimeoutsEnabled` | Accepted by Xcode 27.2. [Run] Wikipedia and Firefox set timeouts. [Repo: test plans] | Adopt. |
| Code coverage | Wikipedia on, NetNewsWire off. [Repo: test plans] | Skip. A percentage on a timer says nothing about whether a Phase ends on time. [Inferred] |

The plan below compiled and ran with two configurations, and Xcode produced `Variant-TSan` build products. [Run] Xcode 27.2 ran it on an iOS 27.0 Simulator, unsigned, which is what the CI image offers. [Run]

### CI

GitHub's standard hosted runners are free on public repositories, and "Larger runners are billed for public repositories". [Doc: [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)] So Signal's `xcode-27-xlarge` is paid and should not be copied.

- `xcode-27` is a standard arm64 label, 3 vCPU and 7 GB. [Doc: [Hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)] Wikipedia uses it. [Repo wikimedia/wikipedia-ios@09fa0f3 .github/workflows/strict_concurrency_check.yml]
- It is still a public preview, with a warning about queueing. [Repo actions/runner-images issue 14404]
- `macos-26` carries Xcode 26.6 at most, so it cannot build an iOS 27 target. [Repo actions/runner-images@4da2307 images/macos/macos-26-arm64-Readme.md]
- On the 2026-10-26 image, `Xcode_27.2.app` is a symlink to the release candidate, 27B48, and not 27B52. Issue 15199 tracks the official build. Installed Simulators are iOS 27.0, plus iPhone Duo on 27.1. [Repo actions/runner-images@4da2307 images/macos/xcode-27-arm64-Readme.md]

**Pinning actions.** GitHub's guidance is to "Pin references to actions to a commit SHA". [Doc: [Secure use](https://docs.github.com/en/actions/reference/security/secure-use)] Firefox does: all 48 action references in the 12 workflows I sampled use full SHAs. The other seven use tags in everything I sampled, for example NetNewsWire's `actions/checkout@v5`, Wikipedia's `@v7`, and DuckDuckGo's `ludeeus/action-shellcheck@master`. [Run: pattern count over up to 12 workflows per repo] Follow GitHub and Firefox, since a pinned SHA costs one Dependabot PR now and then.

**Warnings as errors.** NetNewsWire fails CI by grepping the log. [Repo Ranchero-Software/NetNewsWire@70c5dce buildscripts/fail_on_warnings.sh] `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` on the command line did the same job for app code, and `-Xswiftc -warnings-as-errors` for the package. [Run] Keep both out of the xcconfig. The owner re-signs every 7 days, and an Xcode update that adds a new warning must never block installing the timer the night before training. [Inferred]

**Test output.** `xcodebuild -quiet test` printed about ten lines, including one per test, and `xcrun xcresulttool get test-results summary` returned JSON with counts and failure text. [Run] xcbeautify has open issues on Swift Testing output: no file names under the GitHub renderer (#328), missing issues on parameterized tests (#402, #461) and a missed run summary (#511). [Repo cpisciotta/xcbeautify issues] So its value is lowest for exactly the framework Temper uses. For agent output, van der Lee measured `xcsift` turning 18,200 tokens into 32, and his own hook treats `-quiet` as already filtered. [Author: [Reduce token usage](https://www.avanderlee.com/ai-development/reduce-token-usage-claude-code-codex-cursor/)] `-quiet` is enough for a project this small. [Inferred]

**What a free account rules out.** Mastodon's and Wikipedia's deploy workflows, fastlane match, Xcode Cloud and TestFlight all need paid membership. [Repo: workflow lists; `free-signing.md`] CI cannot install on a device either, since it has no account. So CI proves "builds unsigned from a clean clone, and logic tests pass", and the device proof stays with #9.

### Hooks and task runners

- Firefox, Signal, MobileBuildMCP and steipete's agent-scripts all use plain tracked hooks, and I found no `pre-commit` framework or `lefthook` config in any repo. [Repo: path lists]
- A hook is the only check that runs before a push. In a public repo, CI runs after an identifier has already been published. [Inferred] That is why #12's identifier check belongs there as well as in CI.
- It is not a guarantee. Steinberger says so, and `--no-verify` exists. So CI repeats it. [Author: [Just Talk To It](https://steipete.me/posts/just-talk-to-it)]
- `/usr/bin/make` is on every Mac. isowords, Signal, CodexBar and swift-snapshot-testing use a Makefile, and no repo I read uses `just`. [Repo: path lists] The Makefile below ran here, passed on the worktree with no Swift files (`swift-format` reads stdin if given no paths, so it needs that guard), and failed on a bad sample with exit status 2. [Run]
- Of the repos whose file lists I checked, mise appears only in Periphery's. NetNewsWire uses `brew`, DuckDuckGo uses Mint, and Firefox uses a `.swiftlint-version` file. [Repo: path lists] mise would pin tools outside Xcode, and this plan has none. It costs a config file and a setup step for no gain today. [Inferred]

### Dead code and security

Periphery's page says "Small indie and hobby projects" and "open-source projects of any size" stay free, and that the archived MIT version remains available, with no price or definition of "small" given. [Author: [A new chapter](https://periphery.pro/a-new-chapter)] Only Firefox among the apps has it configured. [Repo mozilla-mobile/firefox-ios@167e2d2 firefox-ios/.periphery.yml] An interval timer with a few dozen files does not earn a commercial beta dependency. The compiler already reports unused locals, and SwiftLint's analyzer is the fallback if this ever matters. [Inferred]

For #12, today's repo state: secret scanning and push protection are both enabled, `main` has no branch protection, and Dependabot security updates are off. [Run: `gh api repos/igorxciv/temper`, `.../branches/main/protection`] GitHub says "Public repositories: Secret scanning runs automatically for free". [Doc: [Secret scanning](https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning)] That page does not list Team IDs as a detected type, and a Team ID is not a credential according to `free-signing.md`. So gitleaks would check for a kind of secret Temper does not have, and would still miss what Temper actually has to protect. The grep is the useful check. [Inferred]

### MCP

**Experts disagree.** Ice Cubes builds and tests through XcodeBuildMCP. [Repo Dimillian/IceCubesApp@98098b9 CLAUDE.md] Majid uses Xcode's MCP. Steinberger says nearly all MCPs should be CLIs. Van der Lee measured Xcode 27.1's MCP on one benchmark at about 100,000 tokens against about 14,000 for his own RocketSim CLI, and counts 54 tools at about 20,000 tokens if loaded upfront. He discloses that RocketSim is his. [Author: [Xcode MCP costs](https://www.avanderlee.com/ai-development/xcode-mcp-simulator-token-costs/)] Wals approves Xcode's prompt daily and calls this the main friction. [Author: [FlowDeck post](https://www.donnywals.com/how-i-use-flowdeck-to-let-my-ai-agent-build-and-run-my-apps/)]

For Temper I pick the CLI. `make check` and `xcodebuild -quiet` cover building and testing, nothing about them needs Xcode open, and no one has to approve anything. Xcode's MCP has one thing a CLI lacks: its Preview Snapshot tool can render light and dark, orientation and type sizes. [Doc: [Xcode 27 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes)] That could help on #11, so it is a later owner choice.

Facts for that choice:

- Setup is `claude mcp add --transport stdio xcode -- xcrun mcpbridge`, after turning on "Allow external agents to use Xcode tools" and opening the project. [Doc: [Giving external agents access](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode)]
- `xcrun mcp-server` is a headless preview that needs `sudo`. Its `--unsafe-always-allow-all-agents` flag is "not a recommended configuration for at-desk use". [Doc: Xcode 27 release notes] [Run: `xcrun mcp-server --help`] Do not use it.
- MobileBuildMCP installs from a Homebrew tap or `npm install -g mobilebuildmcp@latest`, sends error telemetry to Sentry unless `MOBILEBUILDMCP_SENTRY_DISABLED` is set, and "requests xcodebuild to skip macro validation". [Repo getsentry/MobileBuildMCP@2998ac7 README.md] Its old `xcodebuildmcp` name is retired, and the tap still uses it. Expect lookalikes and stale instructions under both names. [Inferred]

### Agent files

Sizes vary from DuckDuckGo's few bullets to CodexBar's long list of rules. Firefox's root file is short and Wikipedia's is a full architecture guide. [Repo: agent files above] Apple's doc says hints can go in `AGENTS.md` or `CLAUDE.md`. [Doc: [Giving external agents access](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode)] `AGENTS.md` plus a one-line `CLAUDE.md` containing `@AGENTS.md` is Firefox's pattern, and it means one file to maintain. [Repo mozilla-mobile/firefox-ios@167e2d2 CLAUDE.md]

Temper already has rules in `temper-ios`, so the root file should hold commands and pointers, about 1.4 KB as in van der Lee's trimmed files. Agent instructions alone are weak: his own count shows agents ignoring one in about a third of builds. Enforce what matters in the Makefile and hook. Keep absolute paths out, unlike Ice Cubes and CodexBar. [Repo: agent files above]

### Skills

**Swift Testing Pro.** This is the assessment `ios-skills.md` deferred. I read all five references and `SKILL.md`, 41,219 bytes in total including the license. [Repo twostraws/Swift-Testing-Agent-Skill@2d6bba1] There are no hidden Unicode format characters. No `curl`, `npx`, subprocess, MCP or hook references. Its only URLs are two links to Hudson's skills, one placeholder and two illustrative fetches in examples. MIT, copyright Paul Hudson. It targets Swift 6.2. [Run: scan]

I tested claims against Swift 6.4.2:

| Claim | Result |
|---|---|
| `.timeLimit(.seconds())` is not allowed | Correct: "'seconds' is unavailable: Time limit must be specified in minutes" [Run] |
| Range confirmations, `#expect(throws: Never.self)`, typed return from `#expect(throws:)`, `withKnownIssue(isolation:)`, `Attachment.record` with `Attachable` and `Codable`, `zip` in `arguments:` | All compiled and passed [Run] |
| Raw-identifier test names | Compiled and passed. `swift-format` accepts them. [Run] |
| Test targets can inherit default isolation | Correct, and it matters here. See the local package section. [Run] |
| `.serialized` "only works on parameterized tests" (line 12 of `async-tests.md`) | Wrong. A `@Suite(.serialized)` of plain async tests ran with a peak of one at a time. [Run] Line 10 of the same file has it right. |
| Exit tests with `#expect(processExitsWith:)` | Passes under `swift test` on macOS. Does not compile for iOS: "'failure' is unavailable: Exit tests are not available on this platform." [Run] The skill does not mention this. |

Fit: its hidden-dependency section covers `UserDefaults` suites and controlling time, which matches Temper's store and clock. Its `.networking` tag advice and `URLSession` mocks have no use here. [Repo: `references/writing-better-tests.md`, `references/async-tests.md`] Recommend it. It is the only one I found that fixes mistakes agents make in the framework Temper mandates, and it adds no scripts.

**Swift Testing Expert (AvdLee).** Covers more, including test plan and Xcode workflow references, and it gets `.serialized` right in the part I read. [Repo AvdLee/Swift-Testing-Agent-Skill@798e9b1 swift-testing-expert/references/parallelization-and-isolation.md] A code search for `processExitsWith` returned nothing. Temper already uses two of Hudson's skills, and a second, larger source on the same topic gives agents two voices on one framework. [Inferred] Skip.

**Others.** AvdLee's Xcode-Build-Optimization (1,268 stars) targets build time problems Temper will not have. [Inferred, repo path list only] Airbnb offers a style skill, off-site, and Temper has no use for its 2-space SwiftFormat style. [Repo airbnb/swift@341e154 README.md] Steipete's `agent-scripts` is a personal fleet of skills for his setup. [Repo: path list] Wikipedia's `ui-test-writer` and DuckDuckGo's `ddg-xcode-add-file` show a pattern worth remembering: project-specific skills written after repeated mistakes. Write one only when that happens. [Inferred]

### Libraries

Temper's runtime rule already excludes these. For test-only code, `swift-clocks` is used by DuckDuckGo and isowords. [Run: code search] A manual clock for a Phase engine should be about 30 lines behind `any Clock<Duration>`, and that spares the first package dependency. [Inferred] Snapshot libraries compare images against a recorded reference. For Temper, glass changes between OS releases, the owner tests on one real phone, and the visual question is legibility in a gym, which an image diff cannot answer. [Inferred]

## Ready-to-use files

Paths are from the repo root. Nothing here contains a personal identifier.

`.swift-format`, replacing the current one: `lineLength` 120, 4 spaces, and the full `rules` map from `xcrun swift-format dump-configuration` with these six also set to `true`. Listing only the six turns every other rule off. See the file in PR #15.

- `AlwaysUseLiteralForEmptyCollectionInit`
- `NeverForceUnwrap`
- `NeverUseForceTry`
- `NeverUseImplicitlyUnwrappedOptionals`
- `NoEmptyLinesOpeningClosingBraces`
- `OmitExplicitReturns`

The 120 width is a judgement call: 4-space SwiftUI chains run out of room at the default 100, and CodexBar uses the same pair. [Run: `dump-configuration` for the default; Repo steipete/CodexBar@897bff3 .swiftformat]

`.editorconfig`, honoured by Xcode since 16 [Doc: Xcode 16 release notes]:

```ini
root = true

[*.swift]
indent_style = space
indent_size = 4
trim_trailing_whitespace = true
insert_final_newline = true
```

`Makefile`:

```make
.PHONY: lint identifiers test check

SWIFT := $(shell git ls-files -co --exclude-standard '*.swift' 2>/dev/null)
OLD_APIS := \b(NavigationView|ObservableObject|StateObject|ObservedObject|EnvironmentObject)\b|\.(navigationBarTitle|navigationBarItems|navigationBarHidden|foregroundColor|cornerRadius|edgesIgnoringSafeArea|actionSheet|tabItem|autocapitalization)\b|\.accentColor\(|@Published|Timer\.publish|@State (var|let) 

lint:
ifneq ($(strip $(SWIFT)),)
	@xcrun swift-format lint --strict --parallel $(SWIFT)
	@! grep -nE '$(OLD_APIS)' $(SWIFT)
endif

identifiers:
	@! git grep -nE '(DEVELOPMENT_TEAM|DevelopmentTeam|PRODUCT_BUNDLE_IDENTIFIER) = ' -- '*.pbxproj'
	@! git grep -nE '/Users/[A-Za-z]' -- '*.pbxproj' '*.xcconfig' '*.xcscheme' '*.xctestplan' 'AGENTS.md'
	@! git grep -nE '^// +Created by ' -- '*.swift' '*.xcconfig'
	@! git ls-files | grep -E 'xcuserdata/|\.mobileprovision$$|\.ipa$$|Config/Local\.xcconfig$$'

test:
	swift test --package-path Packages/TemperCore -Xswiftc -warnings-as-errors

check: identifiers lint test
```

Leave the `test` target out, and `test` out of `check`, until the package exists. The `@State (var|let) ` pattern ends in a space on purpose. The list matches `.cornerRadius` and `.accentColor(` with their dots, so `RoundedRectangle(cornerRadius:)` and `Color.accentColor` stay legal. On a sample, it flagged those four old uses and passed `@State private var` and both legal forms. [Run] `lint` and `identifiers` also passed on this worktree, which has no Swift or project files, and `swift test -Xswiftc -warnings-as-errors` passed on the scratch package. [Run] I never ran `identifiers` through `git grep` against a real violation. Its first pattern, under plain `grep`, matched both signing lines in a fake pbxproj and none in my scratch project once they were removed. [Run]

`.githooks/pre-commit`, marked executable and enabled once per clone with `git config core.hooksPath .githooks`:

```sh
#!/bin/sh
set -eu
make identifiers lint
```

`AGENTS.md`:

```markdown
# Temper

iOS 27 interval timer. Vocabulary is in `GLOSSARY.md`. Swift rules, errata and overrides are in the `temper-ios` skill.

- Before finishing, run `make check`. Fix what it reports. Do not bypass the hook.
- Timing and Phase logic goes in `Packages/TemperCore` and is tested with `make test`.
- Screens and audio go in `Temper/`. Add files by creating them in the folder. Do not edit `project.pbxproj` for that.
- App tests: `xcodebuild -scheme Temper -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -quiet -only-test-configuration Default test`
- Never write a Team ID, device ID, personal bundle ID, email or absolute home path into a tracked file. Those live in `Config/Local.xcconfig`, which is git-ignored.
- Never use the Team picker in Signing & Capabilities on the tracked project.
- Add a line here only when an agent gets something wrong and nothing else catches it.
```

`CLAUDE.md`:

```
@AGENTS.md
```

`Config/Base.xcconfig`, the project-level base configuration. It merges `Signing.xcconfig` from `free-signing.md` into one file. It built and tested with the SDK lines that Xcode's template supplies added, which my hand-written project needed. [Run] Start from the template, and let this override it:

```
IPHONEOS_DEPLOYMENT_TARGET = 27.0
SWIFT_VERSION = 6.0
SWIFT_APPROACHABLE_CONCURRENCY = YES
SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor
SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES
SWIFT_UPCOMING_FEATURE_EXISTENTIAL_ANY = YES
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM =
BUNDLE_ID_PREFIX = org.example
PRODUCT_BUNDLE_IDENTIFIER = $(BUNDLE_ID_PREFIX).$(TARGET_NAME:lower)
#include? "Local.xcconfig"
```

`Packages/TemperCore/Package.swift`, run under `swift test`. [Run]

```swift
// swift-tools-version: 6.4
import PackageDescription

let settings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .defaultIsolation(MainActor.self),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "TemperCore",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [.library(name: "TemperCore", targets: ["TemperCore"])],
    targets: [
        .target(name: "TemperCore", swiftSettings: settings),
        .testTarget(name: "TemperCoreTests", dependencies: ["TemperCore"], swiftSettings: settings),
    ]
)
```

`Temper.xctestplan`, with the test target's real identifier from the project. Keep `TemperUITests` in a separate plan so a logic run never drives the UI. [Inferred]

```json
{
  "configurations": [
    { "id": "11111111-1111-4111-8111-111111111111", "name": "Default", "options": {} },
    {
      "id": "22222222-2222-4222-8222-222222222222",
      "name": "Thread Sanitizer",
      "options": { "threadSanitizerEnabled": true }
    }
  ],
  "defaultOptions": {
    "codeCoverage": false,
    "testExecutionOrdering": "random",
    "testTimeoutsEnabled": true
  },
  "testTargets": [
    {
      "target": {
        "containerPath": "container:Temper.xcodeproj",
        "identifier": "REPLACE_WITH_TEST_TARGET_ID",
        "name": "TemperTests"
      }
    }
  ],
  "version": 1
}
```

Layout, once the app target exists:

```
AGENTS.md  CLAUDE.md  GLOSSARY.md  Makefile  .swift-format  .editorconfig  .gitignore
.githooks/pre-commit
.github/workflows/ci.yml  .github/dependabot.yml
Config/Base.xcconfig  Config/Local.xcconfig.example  Config/Local.xcconfig (ignored)
Temper.xcodeproj/  Temper.xctestplan
Temper/  TemperTests/  TemperUITests/
Packages/TemperCore/
docs/research/
```

`.github/workflows/ci.yml`. The `identifiers` job can land now. The `app` job waits for the app target. I could not run this on GitHub. SHAs are the latest releases as of today, resolved through the API from `actions/checkout` v7.0.1 and `actions/upload-artifact` v7.0.2.

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  identifiers:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - run: make identifiers

  app:
    runs-on: xcode-27
    timeout-minutes: 30
    env:
      DEVELOPER_DIR: /Applications/Xcode_27.2.app/Contents/Developer
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
        with:
          persist-credentials: false
      - run: make lint test
      - name: Test on Simulator, unsigned
        run: >
          xcodebuild -scheme Temper
          -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
          -resultBundlePath "$RUNNER_TEMP/Temper.xcresult"
          -quiet
          CODE_SIGNING_ALLOWED=NO
          SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
          test
      - if: failure()
        uses: actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2
        with:
          name: xcresult
          path: ${{ runner.temp }}/Temper.xcresult
          retention-days: 7
```

`.github/dependabot.yml`, so pinned SHAs do not go stale:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: monthly
```

Additions for `temper-ios`, under Errata and Overrides:

```markdown
- Swift Testing Pro's `references/async-tests.md` line 12 says `.serialized` only works on parameterized tests. On a suite it serializes everything.
- Exit tests (`#expect(processExitsWith:)`) do not compile for iOS. Use them only in `Packages/TemperCore`, which runs on macOS under `swift test`.
- Under main-actor default isolation, test functions run on the main actor. Mark a suite `nonisolated` to exercise off-main code, and keep timing assertions out of the Thread Sanitizer configuration.
- Swift Testing Pro's `.networking` tag and `URLSession` mock guidance has no use here.
```

## Decision table

| Practice | Decision | Exact config or pin | Why, and what it costs |
|---|---|---|---|
| `AGENTS.md`, `CLAUDE.md` as `@AGENTS.md` | Adopt now | Files above, about 1 KB | One place for commands. Costs tokens every session, so it stays an index. |
| Swift Testing Pro | Adopt when the app target exists (owner approval) | `twostraws/Swift-Testing-Agent-Skill@2d6bba14a3c8bf3694f218b92fffe617c41ae43e`, top-level `swift-testing-pro/SKILL.md` and `references/`, plus `LICENSE`, byte-identical, errata in `temper-ios` | Fixes agent mistakes in the mandated framework, no scripts. Costs 41 KB on demand and diffs on update. |
| Swift Testing Expert (AvdLee), build-optimization, Airbnb skill, agent-scripts | Skip | | Overlap, or problems Temper lacks. |
| Xcode MCP | Skip now, owner choice at #11 | If chosen: `claude mcp add --transport stdio xcode -- xcrun mcpbridge`, user scope, no repo file | CLI covers build and test. Costs about 20,000 tokens of tool definitions by one author's estimate, and needs Xcode open. |
| MobileBuildMCP (XcodeBuildMCP), FlowDeck | Skip | | npm or tap install, default telemetry, skips macro validation. FlowDeck has a license step. |
| Plain `.xcodeproj` with buildable folders | Adopt when the app target exists | Xcode's template, committed | No tool to open a clone, agents add files without touching the project. Costs a guard against signing values. |
| XcodeGen, Tuist | Skip | | One target. XcodeGen's Xcode 27 support is unreleased. Costs an install on every clone. |
| One tracked xcconfig plus ignored local | Adopt when the app target exists | `Config/Base.xcconfig` above | Keeps identifiers out, merges `free-signing.md`. Costs one rule: never use the Team picker. |
| One local package, `TemperCore` | Adopt when the app target exists | `Package.swift` above | Tests need no simulator or app launch, 1.5 s warm. Costs `public` keywords, settings written twice, tests run on macOS only. |
| More packages, feature modules | Skip | | Scale practice. Costs manifests and access control for no gain. |
| `swift-format` from Xcode, six extra rules | Adopt now | `.swift-format` above, `xcrun swift-format` (6.4.4) | Free, versions with Xcode, and no Swift exists yet to reformat. Costs losing SwiftFormat's larger rule set. |
| SwiftFormat | Skip | | Overlaps. Costs an install and a pin. |
| SwiftLint | Skip, with fallback | If triggered: `swiftlint = "0.65.1"` via mise, `only_rules` above | The grep covers the two rules that matter most. Costs a binary and a pin. Reconsider at 25 grep names, comment false positives, or for accessibility rules. |
| Grep for old APIs and `@State` | Adopt now | `OLD_APIS` in the Makefile | Catches what the compiler and `swift-format` miss, in one line. Costs occasional false hits in comments. |
| `.editorconfig` | Adopt now | File above | Xcode indents as `swift-format` expects. Costs 6 lines. |
| Swift Testing in package and app, XCUIAutomation for UI | Adopt when the app target exists | Already settled | No change. |
| `.xctestplan` | Adopt when the app target exists | `Temper.xctestplan` above | One place for options. Costs a file with a target ID in it. |
| Thread Sanitizer configuration | Adopt when the app target exists | `"threadSanitizerEnabled": true` | Catches races behind `@unchecked Sendable` in audio code, shown by test. Costs a second run, Simulator only, and timing checks must stay out. |
| Address Sanitizer | Adopt when #10 uses unsafe buffers | Third configuration: `"addressSanitizer": { "enabled": true }` | No unsafe code yet, and one launch crash seen. Costs memory and possible flakiness. |
| Undefined Behavior Sanitizer | Skip | | Apple says it covers C-based languages only. |
| `parallelizable` in the plan | Skip | Leave unset | Clones cost 30 s. Swift Testing is already parallel in-process. |
| Code coverage | Skip | `"codeCoverage": false` | A percentage does not check timing. |
| Snapshot testing | Skip | | Glass changes per OS, one phone, legibility is a human check. Costs a test dependency and reference images. |
| `swift-clocks` and other test libraries | Skip | Write a small manual clock | About 30 lines against a dependency. |
| GitHub Actions, identifier job | Adopt now | `identifiers` job above, `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1` | Free, repeats the hook for anyone who skips it. Costs seconds of Linux time. Feeds #12. |
| GitHub Actions, app job | Adopt when the app target exists | `runs-on: xcode-27`, `actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9`, unsigned | Proves a clean clone builds without local config. Free on a public repo. Costs preview-image queueing and an RC Xcode for now. |
| Pin actions by SHA, read-only token | Adopt now | As above | GitHub's own advice, and a public repo. Costs a monthly Dependabot PR. |
| Dependabot for Actions | Adopt now | `dependabot.yml` above | Keeps SHAs current. Costs a monthly PR at most. |
| Warnings as errors | Adopt in CI only | `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES`, `-Xswiftc -warnings-as-errors` | Stays clean with no risk to the weekly re-sign. Costs nothing locally. |
| xcbeautify, xcsift, xcpretty | Skip | `-quiet`, `xcrun xcresulttool get test-results summary` | Open Swift Testing issues in xcbeautify. `-quiet` gave about ten lines. Reconsider xcsift if logs bloat agent sessions. |
| fastlane, Xcode Cloud, TestFlight, match | Skip | | Need a paid membership or have nothing to deploy to. |
| Periphery | Skip | | Commercial transition, archived repo, small codebase. |
| `pre-commit` hook, plain and tracked | Adopt now | `.githooks/pre-commit` above, `git config core.hooksPath .githooks` | The only check before an identifier goes public. Feeds #12. Costs one setup command per clone, and can be bypassed. |
| `pre-commit` framework, lefthook, Husky | Skip | | Install for a two-line script. |
| Makefile | Adopt now | Above, using `/usr/bin/make` | Same commands for agent, hook and CI. Costs tab-sensitive syntax. |
| `just` | Skip | | An install for what `make` already does. |
| mise | Skip | Use only if SwiftLint is adopted | Nothing to pin. |
| `.xcode-version` | Skip | | Nothing reads it here. `ci.yml` and `AGENTS.md` state the version. |
| gitleaks, trufflehog | Skip | | GitHub's free scanning is already on, Temper holds no credentials, and I would not expect either tool to flag a Team ID. Feeds #12. |
| Grep guard for identifiers | Adopt now | `make identifiers` | Covers what scanners miss. Costs an occasional false hit. Feeds #12. |
| Branch ruleset on `main` | Adopt with #12 | Block force pushes and deletion, require `identifiers` once CI exists | `main` is unprotected today. Owner has to set it. Costs a PR for each change, or allow an admin bypass. |
| actionlint, zizmor in CI | Skip | | Two small workflow files. Another pinned tool to keep current. DuckDuckGo runs actionlint from an unpinned `latest` image, so copying its setup would add risk. |
| Danger, Mergify, code owners | Skip | | Team review tools. |
| Third-party runtime libraries, TCA | Skip | | Settled. |

## Needs the owner's approval

Under the Safety rule in `temper-ios`:

| Item | Type | Recommendation |
|---|---|---|
| Swift Testing Pro at `2d6bba14a3c8bf3694f218b92fffe617c41ae43e` | Skill | **Approve.** Reviewed in full, no scripts, MIT, one wrong line and one gap covered by the errata above. Leave out `agents/`, assets, manifests and the nested `skills/` copy, as in #8. |
| Xcode MCP through `xcrun mcpbridge` | MCP server | **Not now.** Reconsider at #11 for preview rendering. User scope only, no `.mcp.json` in the repo. |
| `xcrun mcp-server enable`, with or without `--unsafe-always-allow-all-agents` | MCP server, `sudo` | **Refuse.** An early preview by Apple's own description, and it is a machine-wide permission. |
| MobileBuildMCP | MCP server | **Refuse.** |
| Any script from a skill | Script | None needed by this plan. |
| Other skills in this note | Skill | **Refuse**, as above. |

These fall outside the Safety rule, but the owner still has to do or review them:

- `AGENTS.md` and `CLAUDE.md` change what agents load, so review them as a PR.
- `git config core.hooksPath .githooks`, once per clone.
- The branch ruleset, in repo settings.

## Not verified

- **SwiftLint, SwiftFormat, XcodeGen, Tuist, Periphery, xcbeautify, xcsift, mise tool installs, gitleaks:** not installed and not run, by instruction. Everything about them comes from their repos and docs. In particular I could not confirm SwiftLint 0.65.1 parses Swift 6.4 raw identifiers, which is part of why it is not recommended now.
- **The CI workflow:** never run on GitHub. `xcode-27` queue times, whether `make` behaves the same on the runner, and whether the 27.2 release candidate behaves like 27B52 are all unknown. `actionlint` was not run on it.
- **Real project files:** my scratch `.xcodeproj` was hand-written. A project Xcode creates may differ in object version and defaults, and the surveyed projects show values from 54 to 76 with XcodeGen listing 110 for Xcode 27. The test plan JSON keys worked here, but Xcode's editor may rewrite them.
- **Warnings flag and packages:** `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` failed on app code. I did not confirm it reaches local package targets under `xcodebuild`, which is why the Makefile passes the separate flag.
- **Address Sanitizer crash:** seen on one Simulator device and not on another, cause not established. Simulator daemons were crashing at the same time, so this may be the machine and not the sanitizer.
- **Thread Sanitizer failure text:** the result bundle says "Crash: Temper" on the racy test, with `TEST FAILED`, and the same test passes under the Address configuration. On `swift test` the report names ThreadSanitizer directly. I infer the same cause on the Simulator.
- **Timing numbers:** one small scratch project on one Mac, a few runs each. Treat them as rough sizes.
- **Code search:** GitHub's index covers default branches and one search hit an API rate limit (`xcresulttool` on NetNewsWire). I checked test plans directly, but `xcscheme` files only by search.
- **Partly read repos:** as marked in the table. I did not read all of DuckDuckGo, Signal, Firefox or Wikipedia, whose workflow counts are large. CodexBar's and RepoBar's CI were read only in part, so their cells are blank.
- **Xcode MCP:** not connected, by instruction. `xcrun mcp-server status` reported permission enabled and the server not running. The 54-tool and token figures are van der Lee's, from one benchmark, and he sells a competing tool.
- **Needing a login, video or paywall:** I watched no talks or videos, including Hudson's. I read no paid course material from van der Lee, Wals or Point-Free. FlowDeck's pricing was not stated in the post. Author posts were read through a fetch tool that summarises pages, so short quotes from them should be checked against the page before being reused. Steinberger's post shows no date, so its date is an inference from a link inside it.
- **Tuist:** the page I read mentions neither account nor telemetry, so I make no claim about either.
- **Periphery on Xcode 27:** the archived 3.8.0 is from 2026-07-25, and I did not check whether it reads Xcode 27 index stores.
- **Team ID scanning:** GitHub's page does not list Team IDs, and I did not test whether scanning flags one. It is not a credential, so I would not expect it to. [Inferred]
