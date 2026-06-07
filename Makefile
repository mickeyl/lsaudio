SWIFT ?= swift
PREFIX ?= $(HOME)/.local
BINDIR = $(PREFIX)/bin
MANDIR = $(PREFIX)/share/man/man1
BINARY = .build/release/lsaudio
SILENCE = /tmp/lsaudio-smoke-silence.wav

.PHONY: help build debug run all watch check smoke lint man install uninstall clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Targets:\n"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

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

clean: ## Remove build artifacts
	rm -rf .build
