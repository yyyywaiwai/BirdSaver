SHELL := /bin/zsh

PROJECT := BirdSaver.xcodeproj
SCHEME := BirdSaver
APP_NAME := BirdSaver

CONFIGURATION ?= Release
DERIVED_DATA_DIR ?= $(CURDIR)/.build/BirdSaverDerivedData
DIST_DIR ?= $(CURDIR)/dist
BUILT_APP := $(DERIVED_DATA_DIR)/Build/Products/$(CONFIGURATION)/$(APP_NAME).app
OUTPUT_APP := $(DIST_DIR)/$(APP_NAME).app

XCODEBUILD := xcodebuild \
	-project "$(PROJECT)" \
	-scheme "$(SCHEME)" \
	-configuration "$(CONFIGURATION)" \
	-destination "generic/platform=macOS" \
	-derivedDataPath "$(DERIVED_DATA_DIR)"

ifdef CODE_SIGNING_ALLOWED
XCODEBUILD += CODE_SIGNING_ALLOWED=$(CODE_SIGNING_ALLOWED)
endif

.DEFAULT_GOAL := app

.PHONY: app debug release clean open

app:
	$(XCODEBUILD) build
	@test -d "$(BUILT_APP)" || { echo "$(BUILT_APP) が生成されませんでした" >&2; exit 1; }
	@mkdir -p "$(DIST_DIR)"
	@rm -rf "$(OUTPUT_APP)"
	@ditto "$(BUILT_APP)" "$(OUTPUT_APP)"
	@echo "生成完了: $(OUTPUT_APP)"

debug:
	@$(MAKE) app CONFIGURATION=Debug

release:
	@$(MAKE) app CONFIGURATION=Release

open: app
	@open "$(OUTPUT_APP)"

clean:
	@rm -rf "$(DERIVED_DATA_DIR)" "$(OUTPUT_APP)"
	@rmdir "$(DIST_DIR)" 2>/dev/null || true
