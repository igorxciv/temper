.PHONY: check lint identifiers

# Prototypes are throwaway, so style checks skip them. `identifiers` still covers them.
SWIFT := $(shell git ls-files -co --exclude-standard -- '*.swift' ':!:Prototypes/*' 2>/dev/null)
OLD_APIS := \b(NavigationView|ObservableObject|StateObject|ObservedObject|EnvironmentObject)\b|\.(navigationBarTitle|navigationBarItems|navigationBarHidden|foregroundColor|cornerRadius|edgesIgnoringSafeArea|actionSheet|tabItem|autocapitalization)\b|\.accentColor\(|@Published|Timer\.publish|@State (var|let)\b

check: identifiers lint

lint:
ifneq ($(strip $(SWIFT)),)
	@xcrun swift-format lint --strict --parallel $(SWIFT)
	@! grep -nE '$(OLD_APIS)' $(SWIFT)
endif

identifiers:
	@! git grep -nE '(DEVELOPMENT_TEAM|DevelopmentTeam|PRODUCT_BUNDLE_IDENTIFIER) = ' -- '*.pbxproj'
	@! git grep -nE 'DEVELOPMENT_TEAM *= *[A-Z0-9]{10}' -- '*.xcconfig'
	@! git grep -nE '/Users/[A-Za-z]' -- ':!:Makefile'
	@! git grep -nE '^// +Created by ' -- '*.swift' '*.xcconfig'
	@! git ls-files | grep -E 'xcuserdata/|\.mobileprovision$$|\.ipa$$|(^|/)Local\.xcconfig$$'
