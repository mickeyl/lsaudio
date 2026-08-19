.DEFAULT_GOAL := help

SWIFT ?= swift
XCODEGEN ?= xcodegen
XCODEBUILD ?= xcodebuild
PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man/man1
BINARY = .build/release/lsaudio
SILENCE = /tmp/lsaudio-smoke-silence.wav
MAC_PROJECT = macOS/LSAudio.xcodeproj
MAC_SCHEME = LSAudio
MAC_DERIVED_DATA ?= macOS/DerivedData
MAC_VERSION = $(shell awk '/MARKETING_VERSION:/ { print $$2; exit }' macOS/project.yml)
MAC_RELEASE_APP = $(MAC_DERIVED_DATA)/Build/Products/Release/LSAudio.app
MAC_DIST_DIR = macOS/Dist
MAC_DIST_ARCHIVE = $(MAC_DIST_DIR)/LSAudio-$(MAC_VERSION)-macOS.zip
MAC_SIGN_IDENTITY ?= Developer ID Application: Michael Lauer (NANNL9SK66)
NOTARY_PROFILE ?=

.PHONY: help build debug run all watch check smoke lint man install uninstall mac-generate mac-build mac-test mac-run mac-package mac-release clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Targets:\n"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the release binary
	$(SWIFT) build -c release

debug: ## Build the debug binary
	$(SWIFT) build

run: build ## Run lsaudio from the source tree
	@$(BINARY)

all: build ## Run lsaudio --all from the source tree
	@$(BINARY) --all

watch: build ## Run lsaudio --watch from the source tree
	@$(BINARY) --watch || test $$? -eq 130

check: build ## Build and show CLI help
	$(BINARY) --help

smoke: build ## End-to-end test against a (silent) stray afplay
	@set -e; \
	python3 -c "import wave; w = wave.open('$(SILENCE)', 'w'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(8000); w.writeframes(b'\x00\x00' * 8000 * 30); w.close()"; \
	afplay $(SILENCE) & APID=$$!; \
	trap 'kill $$APID 2>/dev/null || true; rm -f $(SILENCE)' EXIT; \
	sleep 1; \
	echo "- detects the player:"; \
	$(BINARY) --plain | grep "^$$APID" || { echo "FAIL: afplay (PID $$APID) not listed"; exit 1; }; \
	echo "- JSON parses:"; \
	$(BINARY) --json | python3 -m json.tool > /dev/null && echo "  ok"; \
	echo "- dry-run leaves it alive:"; \
	$(BINARY) kill --dry-run $$APID; \
	kill -0 $$APID; \
	echo "- no-match exits 1:"; \
	if $(BINARY) kill --force this-matches-nothing 2>/dev/null; then echo "FAIL: expected exit 1"; exit 1; fi; \
	echo "  ok"; \
	echo "- kills by PID:"; \
	$(BINARY) kill --force $$APID; \
	sleep 1; \
	if kill -0 $$APID 2>/dev/null; then echo "FAIL: PID $$APID survived"; exit 1; fi; \
	echo "smoke test passed"

lint: ## Run swiftlint over the sources
	swiftlint lint --quiet Sources

man: ## Preview the man page
	man ./lsaudio.1

install: build ## Install binary and man page into PREFIX (default: ~/.local)
	install -d $(BINDIR) $(MANDIR)
	install $(BINARY) $(BINDIR)/lsaudio
	install -m 644 lsaudio.1 $(MANDIR)/lsaudio.1

uninstall: ## Remove binary and man page from PREFIX
	rm -f $(BINDIR)/lsaudio $(MANDIR)/lsaudio.1

mac-generate: ## Generate the macOS Xcode project
	cd macOS && $(XCODEGEN) generate

mac-build: mac-generate ## Build the native macOS menu-bar app
	$(XCODEBUILD) -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -configuration Debug -derivedDataPath $(MAC_DERIVED_DATA) build

mac-test: ## Run the shared core and CLI tests
	$(SWIFT) test

mac-run: mac-build ## Build and launch the native macOS menu-bar app
	open "$(MAC_DERIVED_DATA)/Build/Products/Debug/LSAudio.app"

mac-package: mac-generate ## Build and package the Developer ID release app
	$(XCODEBUILD) -project $(MAC_PROJECT) -scheme $(MAC_SCHEME) -configuration Release -destination 'generic/platform=macOS' -derivedDataPath $(MAC_DERIVED_DATA) CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$(MAC_SIGN_IDENTITY)" DEVELOPMENT_TEAM=NANNL9SK66 ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS="--timestamp" build
	codesign --verify --deep --strict --verbose=2 "$(MAC_RELEASE_APP)"
	@if codesign -d --entitlements :- "$(MAC_RELEASE_APP)" 2>/dev/null | grep -q com.apple.security.get-task-allow; then \
		echo "ERROR: Release app contains com.apple.security.get-task-allow."; \
		exit 1; \
	fi
	mkdir -p "$(MAC_DIST_DIR)"
	rm -f "$(MAC_DIST_ARCHIVE)"
	ditto -c -k --keepParent --sequesterRsrc --zlibCompressionLevel 9 "$(MAC_RELEASE_APP)" "$(MAC_DIST_ARCHIVE)"
	shasum -a 256 "$(MAC_DIST_ARCHIVE)"

mac-release: ## Notarize and staple the native macOS app
	@if [ -z "$(NOTARY_PROFILE)" ]; then \
		echo "ERROR: Set NOTARY_PROFILE to a notarytool keychain profile."; \
		exit 1; \
	fi
	$(MAKE) mac-package
	xcrun notarytool submit "$(MAC_DIST_ARCHIVE)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(MAC_RELEASE_APP)"
	spctl -a -vvv -t exec "$(MAC_RELEASE_APP)"
	rm -f "$(MAC_DIST_ARCHIVE)"
	ditto -c -k --keepParent --sequesterRsrc --zlibCompressionLevel 9 "$(MAC_RELEASE_APP)" "$(MAC_DIST_ARCHIVE)"
	shasum -a 256 "$(MAC_DIST_ARCHIVE)"

clean: ## Remove build artifacts
	rm -rf .build macOS/DerivedData macOS/Dist
