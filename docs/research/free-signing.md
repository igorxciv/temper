# Free Apple account signing, and keeping signing details out of a public repo

Research for ticket #5. Sources read 2026-11-01. Local checks used Xcode 27.2 (27B52).

Each claim carries one of these labels:

- **Apple**: stated in Apple documentation or terms, linked.
- **Project**: stated in a third-party project's own docs, source or issue tracker, linked.
- **Tested**: observed in a throwaway project on this Mac, using fake values.
- **Inferred**: my reasoning from the sources, not stated by any of them.
- **Not confirmed**: no primary source found, or it needs a real device. These are collected under [What a real install must confirm](#what-a-real-install-must-confirm).

## Short answer

- Background audio is available on a free account, according to Apple's capability table. A real-device check is still needed.
- The limits are 7-day profiles, 3 apps per device, 3 registered devices and 10 App IDs.
- Saved data should survive a normal re-sign. It is lost if the app is deleted, and a change of Apple account would probably force that delete.
- Keep the weekly re-sign from Xcode. Do not adopt a sideloading tool.
- Signing details can live in a git-ignored xcconfig, and that override works. The one weak point is Xcode's Team picker, which needs an automated check.

## Free account limits

All from Apple's [Compare memberships](https://developer.apple.com/support/compare-memberships/) page, section "Enable a personal team in Xcode" (**Apple**):

| Limit | Value |
|---|---|
| App IDs | Up to 10, which expire after 7 days |
| Registered devices | Up to 3, which expire after 7 days |
| Apps per device | Up to 3 |
| Provisioning profile | Expires 7 days from issuance. "You'll need to rebuild and reinstall your app to your device after expiration." |

The same page's table gives free accounts on-device testing with Xcode, and no code-level support, Certificates, Identifiers & Profiles, App Store Connect or Xcode Cloud (**Apple**, read from the page's HTML). I did not research the terms of a paid membership.

[Changing the bundle identifier](https://developer.apple.com/documentation/xcode/changing-the-bundle-identifier) warns that without a membership "the number of App IDs you can register in Xcode is limited, so don't change the bundle ID frequently" (**Apple**).

Apple's page does not say whether re-running from Xcode before day 7 issues a new profile or reuses the current one (**Not confirmed**). That decides whether an early re-sign actually buys a full new week.

### Device setup

- Developer Mode must be on to run apps from Xcode ([Enabling Developer Mode](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device), **Apple**).
- On iOS 27 a device can pair wirelessly in Device Hub. Otherwise, pair by cable once, then run over Wi-Fi with IPv6 on the same network as the Mac. A wirelessly paired device must pair again after an OS upgrade ([Device Hub](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub), **Apple**).
- So the weekly re-sign may not need a cable. Apple does not say whether a Personal Team changes this (**Inferred** that it does not; **Not confirmed**).

## Capabilities, including background audio

From [Supported capabilities (iOS)](https://developer.apple.com/help/account/reference/supported-capabilities-ios/), "Apple Developer" column, which covers free accounts (**Apple**, read from the page's HTML because the text extraction loses the checkmarks):

| Free account | Capabilities relevant to Temper |
|---|---|
| Yes | **Background modes**, App groups, Data protection, HealthKit, Inter-App Audio, Keychain sharing, Maps |
| No | Push notifications, Time Sensitive Notifications, Sustained Execution, Siri, all iCloud capabilities, Sign in with Apple, Push to Talk |

Other evidence on the `audio` mode specifically:

- The table lists "Background modes" as one row and does not list individual modes, so it does not name `audio` (**Inferred** that `audio` is covered).
- `audio` is a value of the `UIBackgroundModes` Info.plist key, which Xcode writes when you tick the mode ([Configuring background execution modes](https://developer.apple.com/documentation/xcode/configuring-background-execution-modes), [UIBackgroundModes](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes), **Apple**). The page does not describe an entitlement for it.
- A throwaway build with `UIBackgroundModes = [audio]` merged into a generated Info.plist produced `["audio"]` in the built app, with no entitlements (**Tested**, Simulator ad hoc signing only, so this says nothing about device enforcement).
- SideStore, which is built to run under free-account signing, [declares `audio`](https://github.com/SideStore/SideStore/blob/cd260851ae99bf1fc946b123db24e89c8cd21dc6/AltStore/Info.plist) and [plays a silent file through a `.playback` session](https://github.com/SideStore/SideStore/blob/cd260851ae99bf1fc946b123db24e89c8cd21dc6/AltStore/Components/BackgroundTaskManager.swift#L33) for background work (**Project**). This suggests the mode works under free signing (**Inferred**).

The mode alone is not enough. The default audio session is silenced by the Silent switch and by locking; the `playback` category is what allows background audio ([Configuring your app for media playback](https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback), **Apple**).

No source reports `audio` running on a free-account iPhone on iOS 27 with a timer-like workload. Ticket #9's on-device run can settle it.

## Saved data across re-sign and reinstall

Temper saves only the last-used Workout values and the Dip setting, so a loss would be a small annoyance. No Apple document covers free-account re-signing directly, so this section is partly inference.

| Event | Saved data | Basis |
|---|---|---|
| Re-run from Xcode over the installed app, same team and bundle ID | Kept | `Documents` and `Library` (except `Caches`) are "guaranteed to be preserved across updates" ([TN2285](https://developer.apple.com/library/archive/technotes/tn2285/_index.html), **Apple**, from 2014 and written for ad hoc and App Store updates). Applying it to Xcode installs is **Inferred**. |
| Profile expires, then re-run from Xcode | Probably kept | Apple says only to "rebuild and reinstall". Expiry does not appear to remove the app or its container (**Inferred**, **Not confirmed**). |
| App deleted from the iPhone | Lost | "Deleting an app removes it and its data" ([iPhone User Guide](https://support.apple.com/guide/iphone/remove-or-delete-apps-iph248b543ca/ios), **Apple**). |
| Bundle ID changed | Probably lost to the new app | A different ID is a different app to the system (**Inferred**). It also uses another App ID. |
| Different Apple account, so a different team | Probably lost | An upgrade with a different App ID prefix is rejected. The documented way round needs a special profile from Apple's Developer Programs ([TN2319](https://developer.apple.com/library/archive/technotes/tn2319/_index.html), **Apple**). The team-to-prefix link and the need to delete the app are **Inferred**. |
| Device backup and restore | Probably kept | `UserDefaults` databases are included in backups ([UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults), **Apple**). Restoring into a working signed app is **Not confirmed**. |

Practical rule: keep one Apple account and one local bundle ID, and re-sign without deleting the app first.

## Automatic-refresh sideloading tools

I read docs and source for assessment only and installed nothing. Both projects are open source under AGPL-3.0 and active: SideStore's latest release is `0.7.0-alpha` (2026-09-15) and AltStore Classic's is `v2.3` (2026-09-30) ([SideStore](https://github.com/SideStore/SideStore), [AltStore](https://github.com/altstoreio/AltStore), **Project**).

**How they work**

- SideStore re-signs with your personal certificate and "uses a specially designed VPN in order to trick iOS into installing them", refreshing in the background to stay within the 7 days ([README](https://github.com/SideStore/SideStore), **Project**).
- That VPN, LocalDevVPN, must be on "any time you wish to install, update, or refresh". A computer is needed for first install ([Prerequisites](https://docs.sidestore.io/docs/installation/prerequisites), **Project**).
- AltStore refreshes in the background "with AltServer" ([docs](https://faq.altstore.io/altstore-classic/your-altstore.md)), or through a Remote AltServer paired with a PC and LocalDevVPN on Wi-Fi ([docs](https://faq.altstore.io/altstore-classic/no-computer-instructions.md)) (**Project**).

**Costs for Temper**

- **Apple Account password held by the tool.** Both store it in the keychain: [SideStore](https://github.com/SideStore/SideStore/blob/cd260851ae99bf1fc946b123db24e89c8cd21dc6/AltStore/Core/Components/Keychain.swift#L54), whose keychain wrapper sets `.synchronizable(true)`, and [AltStore](https://github.com/altstoreio/AltStore/blob/56854e66fef2eac32dad88dcbad1dc131d430e60/AltStore/Operations/AuthenticationOperation.swift#L261) (**Project**). I did not audit everywhere the password travels.
- **Apple's terms.** The [Apple Developer Agreement](https://developer.apple.com/support/downloads/terms/apple-developer-agreement/Apple-Developer-Agreement-20250318-English.pdf) §1 says the account and password "cannot be shared in any way or with anyone", and §3 prohibits using the services to "circumvent the security of any computer network, software, passwords" or technological protection measures (**Apple**). Whether these tools breach it is a legal reading I cannot settle, but they sit close to both clauses (**Inferred**).
- **Third-party servers by default.** SideStore's [default anisette source](https://github.com/SideStore/SideStore/blob/cd260851ae99bf1fc946b123db24e89c8cd21dc6/SideStore/AppConstants.swift#L98) is a project-run server, and an on-device option also exists. Its [FAQ](https://docs.sidestore.io/docs/faq) warns that older shared servers "are known to cause locking of Apple ID's" (**Project**).
- **An app slot.** SideStore counts itself in the 3-app limit, and the 10-App-ID limit still applies ([FAQ](https://docs.sidestore.io/docs/faq), **Project**).
- **Separate data from an Xcode install.** Both append the team ID to the bundle ID ([SideStore](https://github.com/SideStore/SideStore/blob/cd260851ae99bf1fc946b123db24e89c8cd21dc6/SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift#L149), [AltStore](https://github.com/altstoreio/AltStore/blob/56854e66fef2eac32dad88dcbad1dc131d430e60/AltStore/Operations/FetchProvisioningProfilesOperation.swift#L190), **Project**). A tool-installed Temper would likely be a separate app with its own data (**Inferred**).
- **Refresh skips running apps** ([source](https://github.com/SideStore/SideStore/blob/cd260851ae99bf1fc946b123db24e89c8cd21dc6/SideStore/Core/Operations/StandaloneOperations/BackgroundRefreshAppsOperation.swift#L96), **Project**).

**Current reliability on iOS 27**

These are user reports in the projects' trackers, and I did not reproduce them (**Project**, unverified):

- SideStore: sign-in failures on iOS 27 ([#1604](https://github.com/SideStore/SideStore/issues/1604), [#1709](https://github.com/SideStore/SideStore/issues/1709)). On 27.2 a reporter fixed one with a multi-step anisette workaround ([#1693](https://github.com/SideStore/SideStore/issues/1693)).
- SideStore: pairing files stop being recognised after a few hours on 27.0.1 ([#1707](https://github.com/SideStore/SideStore/issues/1707)), and a report that only some anisette servers work ([#1682](https://github.com/SideStore/SideStore/issues/1682)).
- AltStore: a signing identity error on iOS 27 ([#1856](https://github.com/altstoreio/AltStore/issues/1856)) and a Remote AltServer setup failure ([#1803](https://github.com/altstoreio/AltStore/issues/1803)).

**Verdict: viable for determined users, not worth recommending here.** The owner already has a Mac with Xcode and must rebuild to change the app anyway. A tool swaps a predictable weekly step for a password held by a third-party app, reliance on outside servers, and refreshes that can fail without notice, so the app could expire anyway (**Inferred**).

## Keeping signing details out of the repo

### Setup

```
Config/Signing.xcconfig        tracked: neutral defaults, includes the local file last
Config/Local.xcconfig          git-ignored: the owner's real values
Config/Local.xcconfig.example  tracked: placeholders to copy
```

`Config/Signing.xcconfig`, set as the project-level base configuration for Debug and Release:

```
BUNDLE_ID_PREFIX = org.example
DEVELOPMENT_TEAM =
CODE_SIGN_STYLE = Automatic
PRODUCT_BUNDLE_IDENTIFIER = $(BUNDLE_ID_PREFIX).temper
#include? "Local.xcconfig"
```

`Config/Local.xcconfig`:

```
DEVELOPMENT_TEAM = ABCDE12345
BUNDLE_ID_PREFIX = com.yourname
```

Rules:

- `project.pbxproj` must not set `DEVELOPMENT_TEAM` or `PRODUCT_BUNDLE_IDENTIFIER` at project or target level.
- Keep `Config/` outside the app's synchronized folder, and in no target. Apple says to deselect all targets so the file is not embedded in the bundle ([Adding a build configuration file](https://developer.apple.com/documentation/xcode/adding-a-build-configuration-file-to-your-project), **Apple**).
- Each person needs their own prefix, because Xcode blocks setup when a bundle ID is not unique ([Running your app](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices), **Apple**).

The pieces rest on documented behaviour: `#include?` suppresses the missing-file warning, and the last instance of a repeated setting wins (same Apple page). SideStore uses the same pattern with [`#include? "CodeSigning.xcconfig"`](https://github.com/SideStore/SideStore/blob/cd260851ae99bf1fc946b123db24e89c8cd21dc6/Build.xcconfig) and a [sample file](https://github.com/SideStore/SideStore/blob/cd260851ae99bf1fc946b123db24e89c8cd21dc6/CodeSigning.xcconfig.sample) (**Project**).

### Test results

**Tested**, using a hand-written `project.pbxproj` (object version 77, synchronized folder) with fake values. Xcode's New Project wizard and GUI were not used, and no account or signing setting was touched.

| Case | Result |
|---|---|
| No local file, `-showBuildSettings` | Bundle ID `org.example.temper`, team unset, no warning |
| Local file present | Team and bundle ID both come from the local file |
| `DEVELOPMENT_TEAM` hardcoded at target level in `project.pbxproj`, plus local file | **pbxproj value wins**, so the xcconfig override is silently ignored |
| Fresh clone, Simulator build | Succeeds, ad hoc signed, no Team ID |
| Fresh clone, device build | Fails with "Signing for "Temper" requires a development team" |
| Fresh clone, device build with `CODE_SIGNING_ALLOWED=NO` | Succeeds, unsigned, usable as a CI compile check |
| Fake team through local file, device build | Picks up the team, then fails at "No profiles" as expected |
| After builds | `project.pbxproj` contains no local values; `git status` shows the local file ignored; nothing from `Config/` in the app bundle |

The precedence result matches Apple: target values beat project values, and at each level settings in the project beat build configuration files ([Configuring the build settings](https://developer.apple.com/documentation/xcode/configuring-the-build-settings-of-a-target), **Apple**).

So a fresh clone builds for the Simulator with no setup. To run on a device, another person copies the example file and fills in their own values.

### The weak point

Apple's device instructions tell you to choose a team in Signing & Capabilities ([Running your app](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)). Using that picker, or editing the Bundle Identifier field there, very likely writes the value into `project.pbxproj` (**Inferred**, not tried, because it means changing signing settings). That would both publish the value on the next commit and override the local file.

Check before each commit, or in the check ticket #12 is deciding on:

```
git grep -nE '(DEVELOPMENT_TEAM|DevelopmentTeam|PRODUCT_BUNDLE_IDENTIFIER) = ' -- '*.pbxproj'
```

This should match nothing. `DevelopmentTeam` under `TargetAttributes` is the older form as I recall it (**Not confirmed**), and scanning for it costs nothing.

### What commonly leaks

| Location | What it holds | Handling | Basis |
|---|---|---|---|
| `project.pbxproj` | Team ID, bundle ID | Keep in the local xcconfig, scan as above | **Tested** for precedence |
| `*.pbxproj` file references | Absolute paths with a username, if a file is added outside the project | Keep references relative, scan for `/Users/` | **Inferred** |
| New file headers | "Created by <full name>", from `___FILEHEADER___` | Set an empty `FILEHEADER` in `IDETemplateMacros.plist`, and review xcconfig files too | Bundled templates use the macro (**Tested**). [Apple help](https://developer.apple.com/library/archive/documentation/IDEs/Reference/xcode_help-collection/Chapter/Chapter.html) covers the macro, and Apple's own xcconfig example shows a "Created by" line (**Apple**). The per-project plist location is **Not confirmed**. |
| Organization name | `ORGANIZATIONNAME` and `FULLUSERNAME` macros in bundled file templates | Leave the organization neutral, review diffs | **Tested** for the templates |
| `xcuserdata/` | Per-user schemes and window state, in a folder named after the macOS user | Ignore | [Swift.gitignore](https://github.com/github/gitignore/blob/main/Swift.gitignore) ignores it (**Project**). The folder naming is from memory (**Not confirmed**). |
| `.ipa`, `.xcarchive`, `.mobileprovision`, dSYMs | Team ID and device identifiers; a development profile "contains the device" | Ignore, never attach to issues | [Running your app](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices) (**Apple**) for the device. Team ID inside them is **Inferred**. |
| `build/`, DerivedData, logs | Absolute paths with a username | Ignore, redact before pasting | **Tested**: `xcodebuild` errors print absolute paths |
| Git metadata | Author email and name | No-reply address, already a map rule | Map #1 |

GitHub's Swift template does not cover `*.xcarchive`, `*.mobileprovision`, `build/` or the local xcconfig, so add them. For ticket #12:

```
Config/Local.xcconfig
xcuserdata/
*.xcuserstate
*.ipa
*.xcarchive
*.mobileprovision
*.dSYM
*.dSYM.zip
build/
DerivedData/
.DS_Store
```

A Team ID is not a credential. SideStore commits its own and both tools put team IDs in bundle IDs (**Project**). Keeping it out is the map's privacy rule, so a leak would call for a history clean-up, not a credential rotation (**Inferred**).

## What a real install must confirm

1. **Background audio on a free-account iPhone.** With `audio` and a `playback` session, a Cue speaks when locked and when another app is open. Fold this into ticket #9.
2. **Profile lifetime.** Note the expiry date Xcode shows after install, then re-run on day 5 or 6 and see whether the date moves.
3. **What expiry looks like.** Whether the app refuses to launch, and what happens if it is already running at expiry.
4. **Data across expiry.** Save values, let the profile expire, re-run without deleting, and check that they are still there.
5. **Trust step.** Whether the first run needs trusting the developer in Settings. I found no primary source for the current steps.
6. **Wireless re-sign.** Whether a Personal Team can re-sign over Wi-Fi on iOS 27 with no cable.
7. **Xcode GUI behaviour.** On a scratch project, whether a team shows as resolved from the xcconfig with the picker untouched, and what the picker writes to `project.pbxproj`. Also whether a device build needs `-allowProvisioningUpdates` from the command line.
8. **Header macro location.** Whether `Temper.xcodeproj/xcshareddata/IDETemplateMacros.plist` takes effect.

## Recommendation

1. **Keep the free account and re-sign from Xcode.** Nothing found conflicts with the map's Distribution decision. Treat 7 days as a hard limit, and re-sign the evening before training if the profile is near expiry, because an expired app will not open at the gym.
2. **Do not recommend or document an automatic-refresh tool.** If weekly re-signing becomes too annoying, the fallback is a paid membership, not a sideloading tool.
3. **Do not design around capabilities a free account lacks:** Push, Time Sensitive Notifications, Sustained Execution, Siri or iCloud.
4. **Adopt the `Signing.xcconfig` and `Local.xcconfig` setup above**, with no signing values in `project.pbxproj`. Never use the Team picker on the tracked project, and have ticket #12 add the `git grep` check.
5. **Confirm background audio in ticket #9.** It is the one result the map depends on that documentation alone cannot fully settle.
