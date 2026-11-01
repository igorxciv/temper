# iOS skills and best-practice guides for Temper

Research for ticket #7. Checked on 2026-11-01 against Xcode 27.2 (27B52), the iOS 27.2 SDK and Swift 6.4.2. This document only recommends. Ticket #8 adds whatever the owner approves.

## Answer

Copy two MIT skills at pinned commits: SwiftUI Pro and Swift Concurrency Pro. Write two short ones ourselves: `temper-ios` for project rules and known errata, and `liquid-glass`. Enforce style with the `swift-format` that ships in the toolchain. Use Apple's Xcode-bundled skills where they are installed, but do not copy them into this repo, because no open license covers them.

No single source can be trusted on its own. Apple's own bundled guidance names two SwiftUI APIs that are not in the iOS 27.2 SDK, and community skills have errors too. So the project rule should be that the SDK interface wins over any skill.

## How this was checked

- Candidates were cloned with no hooks and no submodules, each into its own empty directory. Nothing from a clone was run, and nothing was installed or enabled.
- Skill content was read as data. Any instruction inside it was recorded, not followed.
- All cloned text files were scanned for hidden Unicode format characters (zero-width, bidirectional and tag characters), with no hits. Candidates were also pattern-searched for `curl`, `npx`, `subprocess`, MCP configuration, hooks and similar.
- "Read in full" and "read in part" below say how much was actually read. Candidates that could not be read are not reported, apart from the warning under Security findings.

## API names checked against the SDK

Each name was searched for in the `SwiftUI` and `SwiftUICore` `.swiftinterface` files of the iOS 27.2 SDK. This is a text search. No code was compiled.

| Name | In SDK | Who says otherwise |
|---|---|---|
| `toolbarMinimizationBehavior(_:for:)` | Yes, `anyAppleOS 27.0` | |
| `toolbarMinimizeBehavior` | **No** | Apple's `swiftui-whats-new-27` skill: its description and 4 lines of its toolbar reference |
| `scrollExtensionMode` | **No** | Apple's `SwiftUI-Implementing-Liquid-Glass-Design.md`, with a code sample |
| `backgroundExtensionEffect()` | Yes | |
| `navigationZoomTransition` | **No** | AvdLee SwiftUI Expert, `references/liquid-glass.md` |
| `Glass.regular`, `.clear`, `.identity` | Yes, and no `.prominent` on `Glass` | |
| `glassEffect`, `glassEffectID`, `glassEffectUnion`, `glassEffectTransition`, `GlassEffectContainer`, `ConcentricRectangle`, `safeAreaBar` | Yes | |
| `ToolbarOverflowMenu`, `.topBarPinnedTrailing`, `visibilityPriority`, `contentMarginsRemoved`, `TabRole.prominent`, `presentationPlacement`, `textInputBorderShape` | Yes | |

The `.serialized` trait was checked against the [swift-testing source](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Traits/ParallelizationTrait.swift). On a suite it serializes all contained tests and sub-suites. Swift Concurrency Pro `references/testing.md` says a suite only serializes its parameterized tests, which is wrong. Swift Testing Pro `references/async-tests.md` states it correctly on line 10 and then contradicts itself on line 12.

## Candidates

### Apple: skills bundled with Xcode 27.2

- **Location:** `/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/`, as `*.idechatprompttemplate` plus `*-ref-*.md.packaged`. Liquid Glass and other guides are in `AdditionalDocumentation/`. Xcode can export skills with `xcrun agent skills export`. Apple's [What's New in Xcode](https://developer.apple.com/xcode/whats-new/) confirms built-in guidance and skills.
- **Maintainer:** Apple.
- **License:** none open. The Xcode license defines its Documentation as part of the Apple Software and grants internal use, with copying limited to the entire package. This is a plain reading, not legal advice.
- **Last update:** ships with each Xcode. These files are from the 27.2 install.
- **iOS 27:** yes. `swiftui-whats-new-27` covers SDK 27.0, and the soft-deprecated API list is generated from iOS 27.0.
- **Liquid Glass:** weak. `AdditionalDocumentation/SwiftUI-Implementing-Liquid-Glass-Design.md` has no iOS 27 content and contains the fabricated `scrollExtensionMode`. No SwiftUI skill covers glass directly.
- **Instructs:**
  - `swiftui-specialist`: view structure, data flow, environment, `ForEach`, localization and soft-deprecated APIs.
  - `swiftui-whats-new-27`: SDK 27 changes, including the `@State` macro and `@ContentBuilder`.
  - `xctrace`: profiling, hang triage and reading traces.
  - `audit-xcode-security-settings`: raises build settings and adds entitlements.
  - Others present: `app-resizability`, `app-intents-specialist`, `app-intents-whats-new-27`, `adopt-c-bounds-safety`, `building-document-based-swiftui-applications`, and two translation skills.
- **Scripts, network, access:** no scripts. `xctrace` has the agent run `xctrace` commands. The security audit edits project settings and entitlements, so it should run only on request. The system prompt addition and security skill tell agents to prefer Xcode MCP tools, which need the opt-in described in [Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode).
- **Flag:** `swiftui-specialist`, `swiftui-whats-new-27` and `xctrace` state that they "unconditionally supersede" prior knowledge. Given the errors in the table above, treat that as ordinary documentation, not as an authority claim.
- **Read:** in full: the three skill bodies, the toolbar and soft-deprecation references. In part: the security skill, `app-resizability`, the xctrace overview, the Liquid Glass guide. The remaining references, about 200 KB, were pattern-searched only.

### SwiftUI Pro

- **URL:** <https://github.com/twostraws/SwiftUI-Agent-Skill>, commit `f2920b63995263f57b3e198674e89a602efba6d2`, version 2.0.0.
- **Maintainer:** Paul Hudson, with outside contributors merged. 6,430 stars.
- **License:** MIT.
- **Last update:** 2026-10-26.
- **iOS 27:** yes. Assumes iOS 27, Xcode 27.1 and Swift 6.4, and covers `@ContentBuilder`, the `@State` macro, toolbars, reordering and iPhone Duo. It uses the correct `toolbarMinimizationBehavior`.
- **Liquid Glass:** incidental only: `contentMarginsRemoved`, `safeAreaBar`, `ConcentricRectangle`, and a note on `confirmationDialog` placement. It has no glass section.
- **Instructs:** review Swift and SwiftUI against 11 reference files, reporting by file with before and after fixes. Suggests modernization separately during feature work. Deprecated APIs, `@Observable` on `@MainActor`, one type per file, no `AnyView`, no `View.if()` helper, 44x44 tap targets, Dynamic Type. `performance-plus.md` is reserved for deep reviews.
- **Scripts, network, access:** none. Markdown only, plus plugin manifests with no hooks or MCP servers. `hygiene.md` says to prefer Xcode MCP tools if configured, which is conditional and asks for nothing new. `agents/openai.yaml` allows implicit invocation in Codex and is not needed here.
- **Conflicts with Temper:**
  - "Never use Grand Central Dispatch" may be too strict for audio callbacks. Swift Concurrency Pro's softer wording should win, subject to #10.
  - Gating advice is noise on an iOS 27 minimum, except for iOS 27.1+ APIs.
- **Read:** in full.

### Swift Concurrency Pro

- **URL:** <https://github.com/twostraws/Swift-Concurrency-Agent-Skill>, commit `bee3f69ba17142da148d3c5406f148ed62592b69`.
- **Maintainer:** Paul Hudson. 578 stars.
- **License:** MIT.
- **Last update:** 2026-05-17.
- **iOS 27:** not specifically. Targets Swift 6.2, and the toolchain is now 6.4. The guidance read is language-level and did not conflict with anything checked, but Swift 6.3 and 6.4 changes are not covered.
- **Liquid Glass:** not applicable.
- **Instructs:** review for actor reentrancy, cancellation, continuation misuse, unbounded `AsyncStream` buffers and `Task.detached`. Maps strict-concurrency diagnostics to fixes. Warns against sleep-based tests.
- **Scripts, network, access:** none. Markdown and manifests. Examples contain `URLSession` calls to third-party URLs, which are illustrations only. They must not be copied into Temper, which has no network access.
- **Known error:** `.serialized` on suites, described above.
- **Why it matters here:** the timer and Cue engine (#10) is where concurrency mistakes would cost the most.
- **Read:** in full. Copy the top-level `swift-concurrency-pro/SKILL.md`. The nested `skills/` copy differs only in using `${CLAUDE_SKILL_DIR}` paths and an `argument-hint`.

### Swift Testing Pro (not on the short list yet)

- **URL:** <https://github.com/twostraws/Swift-Testing-Agent-Skill>, commit `2d6bba14a3c8bf3694f218b92fffe617c41ae43e`, 2026-05-17, MIT, Paul Hudson.
- **Coverage:** targets Swift 6.2. Not relevant to Liquid Glass.
- **Instructs:** Swift Testing conventions, confirmations, migration from XCTest. No scripts.
- **Read:** `SKILL.md` and a search of its references only. Assess it fully when the map's "Testing the timer" item is taken up.

### SwiftUI Expert

- **URL:** <https://github.com/AvdLee/SwiftUI-Agent-Skill>, commit `204dba7c67256a8b707ee3fbc5759a824191974f`.
- **Maintainer:** Antoine van der Lee. 3,801 stars.
- **License:** MIT.
- **Last update:** 2026-10-06.
- **iOS 27:** yes in `latest-apis.md` and `toolbar-patterns.md`, including 27.1.
- **Liquid Glass:** has a dedicated reference, but it is written for iOS 26. It teaches `#available(iOS 26, *)` fallbacks, names the nonexistent `navigationZoomTransition`, and says to adopt glass only when explicitly requested. Temper's standing preference is the opposite.
- **Instructs:** a topic router over 33 references, a correctness checklist, and Instruments workflows.
- **Scripts, network, access:** `scripts/record_trace.py` and `analyze_trace.py` shell out to `xctrace` and can launch or attach to apps. Their imports show no network use. The documented examples write traces to `~/Desktop` and use a predictable `/tmp/stop-trace` stop file. A separate maintainer skill in `.agents/` needs a third-party documentation MCP server and write access to the repo. `llms.txt` addresses agents directly and gives an install command using unpinned `npx skills@latest`.
- **Read:** in part: `SKILL.md`, Liquid Glass and performance references, start of `latest-apis.md`, script imports and subprocess calls. The rest was searched.
- **Verdict:** good content, but larger than Temper needs (about 375 KB of references, including macOS, charts and WebKit), and it overlaps SwiftUI Pro. Not recommended.

### Swift Concurrency (AvdLee)

- **URL:** <https://github.com/AvdLee/Swift-Concurrency-Agent-Skill>, commit `d5770817d2622e1585b1f7eaebc791a9cb0959c8`, 2026-09-14, MIT.
- **Coverage:** mentions Xcode 26 defaults, with no iOS 27, Xcode 27 or Swift 6.4 hits. Not relevant to Liquid Glass.
- **Instructs:** always analyze build settings first, ask when they are unknown, and do not use `@MainActor` as a blanket fix. Mostly a sound workflow. Contains course references.
- **Scripts, network, access:** none found in the skill directory.
- **Read:** start of `SKILL.md`, plus searches.
- **Verdict:** a reasonable alternative, but about 230 KB of references against about 50 KB for Swift Concurrency Pro, and no newer on the facts that matter.

### Liquid Glass (heyparsadev)

- **URL:** <https://github.com/heyparsadev/liquid-glass-skill>, commit `443af09db6127cf87895f615051cc644dfd2e693`, version 2.0.0.
- **Maintainer:** single individual. 13 stars. Repo created 2026-05-25.
- **License:** MIT.
- **Last update:** 2026-10-11.
- **iOS 27 and Liquid Glass:** the best match found. It uses the correct API names and has a dedicated iOS 27 reference. Every iOS 27 API name spot-checked from its list is in the SDK.
- **Instructs:** a decision tree (functional layer or content), ten golden rules, then a checklist that includes running its linter.
- **Scripts, network, access:** `scripts/check_glass.py` describes itself as read-only and its imports are standard library only. It was not fully read and was not run. Includes an eval suite, a Gallery app and ten example screens.
- **Read:** in part: `SKILL.md` in full, start of the iOS 27 reference, script imports.
- **Unverified:** its measured contrast figures, and the claim that `UIDesignRequiresCompatibility` is ignored with the 27 SDK. Apple's [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) still mentions that key without a caveat.
- **Verdict:** very useful cross-check while writing our own. Far larger than a one-screen-family timer needs, with a low bus factor.

### Liquid Glass (YordiLorenzo)

- **URL:** <https://github.com/YordiLorenzo/liquid-glass-skills>, commit `a6bac94c5a7a65ac42207452e3e63bb4eb7518e8`, 2026-08-09, MIT, 7 stars.
- **Coverage:** iOS 26 through iOS 27. Every rule has a confidence tag. It correctly flagged `scrollExtensionMode` as fabricated, which this research confirmed.
- **Instructs:** always read an availability file first. Gate glass APIs per platform, which is noise for Temper.
- **Scripts, network, access:** `liquid-glass-motion/scripts/` is a copy of the AvdLee Instruments scripts.
- **License concern:** `ATTRIBUTION.md` says it paraphrases Apple's proprietary material through unofficial mirrors and several unlicensed repos. That makes its provenance harder to accept into a public MIT repo.
- **Read:** `liquid-glass/SKILL.md`, `ATTRIBUTION.md`, start of the availability reference.

### Apple Liquid Glass (DanielJamesTronca)

- **URL:** <https://github.com/DanielJamesTronca/apple-liquid-glass-skill>, commit `324b668c511556df6e5d85b082e2029a6e4ccb5a`, 2026-08-14, MIT, 5 stars.
- **Coverage:** still labels iOS 27 APIs as beta, although [Xcode 27 was released](https://developer.apple.com/news/releases/?id=09142026h) in September 2026.
- **Instructs:** a sensible stop-at-first-no test for whether glass belongs, and it says not to add OS 26 branches when every target is 26 or newer.
- **Scripts, network, access:** the skill workflow runs `scripts/audit_liquid_glass.py`, and its imports show no network or subprocess use. `CONTRIBUTING.md` uses `curl` against Apple's documentation JSON, for contributors only.
- **Read:** start of `SKILL.md`, script imports, searches.

### Dimillian/Skills

- **URL:** <https://github.com/Dimillian/Skills>, commit `05ba982bfeb0d77d3c97d4542b0ee15034d05f84`, 2026-03-29, MIT, Thomas Ricouard.
- **Coverage:** `swiftui-liquid-glass` and `swiftui-performance-audit` have no iOS 27 mentions. The glass skill teaches `#available(iOS 26, *)` and glass on "cards".
- **Instructs:** the performance audit's code-first, then profile, then verify workflow is a good shape.
- **Scripts, network, access:** none in those two skills. Elsewhere the repo has shell scripts and a pre-commit hook.
- **Read:** those two `SKILL.md` files.

### swift-ios-skills

- **URL:** <https://github.com/dpearson2699/swift-ios-skills>, commit `8d90fd121a263355a4fb44fd082af1416a5c1c2a`, 2026-07-31, 1,266 stars.
- **License:** PolyForm Perimeter 1.0.0, not MIT-compatible for our purpose. **Do not copy.**
- **Coverage:** 86 skills, 12 mention iOS 27. The Liquid Glass skill does not.
- **Scripts, network, access:** `.mcp.json` starts a third-party `tessl` MCP server, which would be picked up if the repo were used as-is.
- **Read:** license, `.mcp.json`, start of the Liquid Glass skill.

### Swift API Design Guidelines skill

- **URL:** <https://github.com/Erikote04/Swift-API-Design-Guidelines-Agent-Skill>, commit `36cdc1b5680f5d6c5c52c353a6857d176f4929e8`, 2026-02-18, MIT.
- **Instructs:** restates the official guidelines. Not version-sensitive. No scripts in the skill.
- **Read:** start of `SKILL.md`, searches.
- **Verdict:** link the [official guidelines](https://www.swift.org/documentation/api-design-guidelines/) instead.

### Style sources

- **API Design Guidelines:** [swift.org](https://www.swift.org/documentation/api-design-guidelines/), source last changed 2024-04-07. Link to it. The page carries an Apple copyright notice with no stated content license, so do not copy the text.
- **swift-format:** <https://github.com/swiftlang/swift-format>, Apache-2.0, bundled in the toolchain as `xcrun swift-format` (6.4.4). A build tool, not a runtime dependency. Its default indentation is 2 spaces, while Xcode's agent prompt asks for 4, so the owner should choose. This research recommends 4 to match Xcode.

### Directory only

[twostraws/Swift-Agent-Skills](https://github.com/twostraws/Swift-Agent-Skills) (MIT, 2026-09-04) is a useful index, and it says plainly that listing is not an endorsement. The [skills.sh](https://skills.sh/) search page returned no results to the fetch used here, so install counts were not used.

## Security findings

1. **Lookalike repository, do not use:** `Muscovyduckantonbruckner450/Swift-Agent-Skills` has a name close to the well-known directory, comes from a single-repo account, and its README sends readers to download `assets/Agent_Swift_Skills_pigmental.zip` from the repo. That is a common malware delivery pattern. The zip was not downloaded or inspected, so its contents are unknown. Search results contain many same-named copies of popular skills, so always use the exact owner and commit.
2. **Unpinned installers:** `npx skills add -g -y` and `npx skills@latest` run unpinned code from the registry and install at user level. Copying files at a commit avoids both.
3. **Skills are auto-loaded instructions:** a vendored skill can change agent behaviour on any Swift task, so updates need a reviewed diff.
4. **Apple mirrors:** community repos that mirror Xcode's prompts and skills exist. They are not needed, since the originals are on disk, and they carry the license problem above. They were not read.
5. **MCP:** no recommended item needs one. Adding Xcode's MCP server is a separate decision for the owner, and repo files should not configure it.

## Recommended list

| Item | Action | Pin or source | Covers |
|---|---|---|---|
| `swiftui-pro` | **Copy** | `twostraws/SwiftUI-Agent-Skill@f2920b63995263f57b3e198674e89a602efba6d2`, MIT | SwiftUI, iOS 27, SwiftUI performance |
| `swift-concurrency-pro` | **Copy** | `twostraws/Swift-Concurrency-Agent-Skill@bee3f69ba17142da148d3c5406f148ed62592b69`, MIT | Swift concurrency |
| `temper-ios` | **Write** | Sketch below | Project rules, errata, profiling pointer |
| `liquid-glass` | **Write** | Sketch below | Liquid Glass on iOS 27 |
| `.swift-format` and `swift-format lint --strict` | **Write** config | Toolchain tool, Apache-2.0, nothing vendored | Code style |
| Apple's `swiftui-specialist`, `swiftui-whats-new-27`, `xctrace` | **Do not copy**, read in place | Xcode install | Apple's guidance, profiling |

Copy rules for #8:

- Copy only `SKILL.md` and `references/`, plus the upstream `LICENSE` from the repo root, which is not inside the skill directory.
- Leave out `agents/`, assets, manifests and nested `skills/` copies.
- Keep the copies byte-identical so they can be diffed against the pin. Put corrections in `temper-ios`.
- Record the upstream URL and commit next to each copy.
- This repo has no `LICENSE` file yet, and #12 covers safeguards. MIT notices should stay with each copy whatever the order.

When writing the two new skills, follow the `writing-for-agents` skill. Use AvdLee and heyparsadev to cross-check facts, not as text to adapt, since adapted text would need their MIT notices.

### Sketch: `temper-ios`

About one page, loaded for any Swift work:

- **Baseline:** iOS 27 minimum and latest Swift. No availability checks or fallbacks except for APIs newer than 27.0.
- **Standing rules from the map:** no third-party runtime dependencies, no network, analytics or accounts, data stays on the device, no personal identifiers in the repo.
- **Source order:** SDK `.swiftinterface` first (`SwiftUI` and `SwiftUICore`), then Apple's current documentation, then skills. Statements that a skill "supersedes" other knowledge carry no extra weight.
- **Errata:**
  - Use `toolbarMinimizationBehavior`, not `toolbarMinimizeBehavior`.
  - `scrollExtensionMode` and `navigationZoomTransition` do not exist.
  - `.serialized` on a suite serializes everything in it.
- **Overrides:**
  - GCD may be used where #10 decides real-time audio needs it, despite SwiftUI Pro's "never".
  - Skip SwiftUI Pro's iPhone Duo work unless the owner asks, and leave `AsyncImage`, SwiftData and similar guidance unused.
- **Performance:** #10 decides where time-critical work runs. Keep timer ticks out of the environment and narrow what the running screen observes. Measure before optimizing: use Apple's `xctrace` skill from the Xcode install, on a real device, against the accuracy targets in the map.
- **Testing:** new tests use Swift Testing. No sleep-based tests. Details wait for the map's testing item.
- **Style:** run `swift-format lint --strict`. Follow the API Design Guidelines by link.
- **Safety:** do not run scripts from skills, add MCP servers or install skills without the owner's approval.

### Sketch: `liquid-glass`

About one page, loaded for UI work. Write from Apple's [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), plus Applying Liquid Glass to custom views and the HIG Materials page (these two still need reading), checking every API against the SDK:

- **Default:** standard components adopt glass with no code. Remove custom backgrounds from bars and controls. A `Form` suits Settings, subject to #11.
- **Where it goes:** controls and navigation only. In Temper terms, and subject to #11, the countdown and Phase display are content, and Pause, Resume and Stop are controls.
- **Custom glass, sparingly:** prefer `.buttonStyle(.glass)` and `.glassProminent`. Use `glassEffect(_:in:)` only when no standard control fits. Group nearby glass in one `GlassEffectContainer`. Do not layer glass on glass.
- **Shape and layout:** `ConcentricRectangle` near container edges, standard spacing, no hard-coded control metrics.
- **Legibility:** the Running screen must read at a glance mid-workout, so test with light and dark appearance, Increase Contrast, Reduce Transparency, Reduce Motion and the system glass look setting.
- **Presentation:** attach Stop's `confirmationDialog` to its button so it originates from that control.
- **Not relevant:** iOS 26 fallbacks, `UIDesignRequiresCompatibility`, UIKit, AppKit and widgets.

## Not verified

- No code was compiled, so API checks show that names exist, not how they behave.
- `xcrun agent skills export` was not run. Its existence and `--replace-existing` flag come from the tool's help and binary strings. The `--output-dir` flag claimed by third-party posts was not found there.
- Apple's bundled references, and the partly read candidates, were not read in full, as marked above.
- Apple's licensing of the bundled skills is inferred from the Xcode license, and no statement specific to them was found.
- Whether SwiftUI Pro's and Swift Concurrency Pro's behaviour claims are all correct. A sample was checked, and one error was found in the second.
- Swift 6.3 and 6.4 concurrency changes that Swift Concurrency Pro may be missing were not enumerated.
