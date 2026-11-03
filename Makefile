.PHONY: check lint identifiers test test-app

SWIFT := $(shell git ls-files -co --exclude-standard -- '*.swift' 2>/dev/null)
OLD_APIS := \b(NavigationView|ObservableObject|StateObject|ObservedObject|EnvironmentObject)\b|\.(navigationBarTitle|navigationBarItems|navigationBarHidden|foregroundColor|cornerRadius|edgesIgnoringSafeArea|actionSheet|tabItem|autocapitalization)\b|\.accentColor\(|@Published|Timer\.publish|@State (var|let)\b

check: identifiers lint test

test:
	swift test --package-path Packages/TemperCore -Xswiftc -warnings-as-errors

test-app:
	xcodebuild -scheme Temper -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -quiet -only-test-configuration Default test

lint:
ifneq ($(strip $(SWIFT)),)
	@xcrun swift-format lint --strict --parallel $(SWIFT)
	@! grep -nE '$(OLD_APIS)' $(SWIFT)
endif
	@# Temper has no third-party packages and no network access.
	@! git grep -nE 'XCRemoteSwiftPackageReference|\.package\(url:' -- '*.pbxproj' '*Package.swift'
	@! git grep -nE '\b(URLSession|NWConnection|NWPathMonitor)\b|^import Network\b' -- '*.swift'

identifiers:
	@! git grep -nE '(DEVELOPMENT_TEAM|DevelopmentTeam|PRODUCT_BUNDLE_IDENTIFIER) = ' -- '*.pbxproj'
	@! git grep -nE 'DEVELOPMENT_TEAM *= *[A-Z0-9]{10}' -- '*.xcconfig'
	@! git grep -nE 'BUNDLE_ID_PREFIX *=' -- '*.xcconfig' | grep -vE 'BUNDLE_ID_PREFIX *= *org\.example *$$'
	@! git grep -nE '/Users/[A-Za-z]' -- ':!:Makefile'
	@! git grep -nE '^// +Created by ' -- '*.swift' '*.xcconfig'
	@! git ls-files | grep -E 'xcuserdata/|\.mobileprovision$$|\.ipa$$|\.jsonl$$|(^|/)Local\.xcconfig$$'
