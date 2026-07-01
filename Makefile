# World Clock plasmoid — build / release helper
#
# Common targets:
#   make            # show this help
#   make validate   # lint QML, check XML/JSON, verify the package
#   make release    # validate, then build the uploadable .plasmoid in dist/
#   make install    # install/upgrade into the current user's Plasma
#   make uninstall  # remove it again
#   make clean      # delete build artifacts

PLUGIN_ID := org.kde.plasma.multitzclock
SRC_DIR   := package
DIST_DIR  := dist

# Read the version straight out of the package metadata so there is a single
# source of truth: bump KPlugin.Version in package/metadata.json for a release.
VERSION := $(shell python3 -c "import json;print(json.load(open('$(SRC_DIR)/metadata.json'))['KPlugin']['Version'])")

PLASMOID := $(DIST_DIR)/$(PLUGIN_ID)-$(VERSION).plasmoid

QML_FILES := $(wildcard $(SRC_DIR)/contents/ui/*.qml) $(SRC_DIR)/contents/config/config.qml

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo "World Clock plasmoid — version $(VERSION)"
	@echo
	@echo "Targets:"
	@echo "  validate    Lint QML and validate metadata.json / main.xml"
	@echo "  release     Validate and build $(PLASMOID)"
	@echo "  package     Build the .plasmoid without validating"
	@echo "  install     Install or upgrade into the current user's Plasma"
	@echo "  uninstall   Remove the widget from Plasma"
	@echo "  clean       Remove the dist/ directory"

.PHONY: validate
validate:
	@echo ">> Validating metadata.json"
	@python3 -c "import json;json.load(open('$(SRC_DIR)/metadata.json'))"
	@echo ">> Validating config/main.xml"
	@xmllint --noout $(SRC_DIR)/contents/config/main.xml
	@echo ">> Linting QML"
	@for f in $(QML_FILES); do qmllint "$$f" || exit 1; done
	@echo ">> OK"

# Build the uploadable archive. A .plasmoid is a zip with metadata.json at its
# root, so we zip from inside the package directory.
$(PLASMOID): $(SRC_DIR)/metadata.json $(shell find $(SRC_DIR)/contents -type f)
	@mkdir -p $(DIST_DIR)
	@rm -f $(PLASMOID)
	@cd $(SRC_DIR) && zip -r -q -X "$(CURDIR)/$(PLASMOID)" metadata.json contents \
		-x '*~' '*.bak' '*/.*'
	@echo ">> Built $(PLASMOID)"

.PHONY: package
package: $(PLASMOID)

.PHONY: release
release: validate package
	@echo
	@echo "Release $(VERSION) ready:"
	@echo "  $(PLASMOID)"
	@unzip -l $(PLASMOID) | sed 's/^/    /'
	@echo
	@echo "Upload this file at https://store.kde.org (Plasma 6 -> Plasma Widgets)."
	@echo "For updates, bump KPlugin.Version in $(SRC_DIR)/metadata.json first."

.PHONY: install
install:
	@if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$(PLUGIN_ID)"; then \
		kpackagetool6 --type Plasma/Applet --upgrade $(SRC_DIR); \
	else \
		kpackagetool6 --type Plasma/Applet --install $(SRC_DIR); \
	fi

.PHONY: uninstall
uninstall:
	kpackagetool6 --type Plasma/Applet --remove $(PLUGIN_ID)

.PHONY: clean
clean:
	rm -rf $(DIST_DIR)
