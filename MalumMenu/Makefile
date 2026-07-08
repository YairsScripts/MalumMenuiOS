# ============================================================================
# Makefile – Theos build configuration for MalumMenu (.dylib tweak)
# ============================================================================
# Prerequisites:
#   1. Install Theos: https://theos.dev/docs/installation
#   2. Set $THEOS to point to your Theos installation
#   3. Export your signing certificate:
#        export CODESIGN_IPA_NAME="iPhone Developer: ..."
#   4. Build:  make package
#   5. The resulting .deb will contain the .dylib under /Library/MobileSubstrate/
#      (or use make package FINALPACKAGE=1)
# ============================================================================

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MalumMenu

# ── Source files ─────────────────────────────────────────────────────────────
MalumMenu_FILES = TweakEntry.mm Hooks.mm FloatingOverlay.mm

# ── Frameworks ───────────────────────────────────────────────────────────────
MalumMenu_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore

# ── Libraries ────────────────────────────────────────────────────────────────
MalumMenu_LDFLAGS = -lsubstrate -lobjc -lc++

# ── Architecture ─────────────────────────────────────────────────────────────
ARCHS = arm64
TARGET = iphone:14.0:13.0

# ── Code signing (sideloadly-compatible if built with proper entitlements) ──
MalumMenu_CODESIGN_FLAGS = -S

include $(THEOS_MAKE_PATH)/tweak.mk

# ── Helper: install to an IPA for sideloading ───────────────────────────────
# Usage: make sideload IPA=/path/to/AmongUs.ipa
sideload:
	@echo "Extracting $(IPA)..."
	unzip -qo "$(IPA)" -d .tmp_sideload 2>/dev/null || unzip -qo "$(IPA)" -d .tmp_sideload
	@echo "Injecting $(TWEAK_NAME).dylib..."
	cp -f $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/$(TWEAK_NAME).dylib .tmp_sideload/Payload/*.app/
	@echo "Repacking..."
	cd .tmp_sideload && zip -qry ../$(TWEAK_NAME)_injected.ipa .
	rm -rf .tmp_sideload
	@echo "Done: $(TWEAK_NAME)_injected.ipa"
