SHELL := /bin/bash
CURDIR != pwd
PKG_ROOT := $(CURDIR)/pkg/erase-install/payload
PKG_SCRIPTS := $(CURDIR)/pkg/erase-install/scripts
PKG_BUILD := $(CURDIR)/pkg/erase-install/build
GITHUB_TOKEN_FILE := /Users/Shared/gh_token
PKG_VERSION :=$(shell awk -F '=' '/^version=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"')
RELEASE_TAG := v$(PKG_VERSION)
PKG_FILE := $(PKG_BUILD)/erase-install-$(PKG_VERSION).pkg
SIGN_ID_PKG ?= Graham Pugh

all: build

.PHONY : build
build: 
	@echo
	@echo "## Copying erase-install.sh into /Library/Management/erase-install"
	mkdir -p "$(PKG_ROOT)/Library/Management/erase-install"
	cp "$(CURDIR)/erase-install.sh" "$(PKG_ROOT)/Library/Management/erase-install/erase-install.sh"
	chmod 755 "$(PKG_ROOT)/Library/Management/erase-install/erase-install.sh"

	@echo
	@echo "## Copying icons folder into /Library/Management/erase-install"
	cp -r "$(CURDIR)/icons" "$(PKG_ROOT)/Library/Management/erase-install/"
	chmod 755 "$(PKG_ROOT)/Library/Management/erase-install/icons"
	chmod 644 "$(PKG_ROOT)/Library/Management/erase-install/icons/"*

	mkdir -p "$(PKG_SCRIPTS)"

	@echo
	swiftdialog_tag=$$(awk -F '=' '/swiftdialog_tag_required="v/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Downloading swiftDialog $$swiftdialog_tag" ;\
	github_token=$$(cat $(GITHUB_TOKEN_FILE)) ;\
	swiftdialog_api_url="https://api.github.com/repos/swiftDialog/swiftDialog/releases" ;\
	swiftdialog_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$swiftdialog_api_url/tags/$$swiftdialog_tag" --header "Authorization: Bearer $$github_token" --header "X-GitHub-Api-Version: 2022-11-28" | /usr/bin/plutil -extract 'assets.0.browser_download_url' raw -) ;\
	echo "## Downloading swiftDialog from $$swiftdialog_url" ;\
	curl -L "$$swiftdialog_url" -o "/private/tmp/swiftDialog.pkg" ;\
	echo "## Downloaded swiftDialog $$swiftdialog_tag" ;\
	\
	echo "## Extracting Dialog.app from swiftDialog pkg" ;\
	pkgutil --expand "/private/tmp/swiftDialog.pkg" "/private/tmp/swiftDialog_expanded" ;\
	mkdir -p "/private/tmp/swiftDialog_payload" ;\
	cd "/private/tmp/swiftDialog_payload" && cat "/private/tmp/swiftDialog_expanded/tmp-package.pkg/Payload" | gunzip -dc | cpio -i ;\
	cp -r "/private/tmp/swiftDialog_payload/Library/Application Support/Dialog/Dialog.app" "$(PKG_ROOT)/Library/Management/erase-install/Dialog.app" ;\
	rm -rf "/private/tmp/swiftDialog_expanded" "/private/tmp/swiftDialog_payload" "/private/tmp/swiftDialog.pkg"

	@echo
	swiftdialog_bigsur_tag=$$(awk -F '=' '/swiftdialog_bigsur_tag_required="v/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Downloading swiftDialog $$swiftdialog_bigsur_tag" ;\
	github_token=$$(cat $(GITHUB_TOKEN_FILE)) ;\
	swiftdialog_api_url="https://api.github.com/repos/swiftDialog/swiftDialog/releases" ;\
	swiftdialog_bigsur_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$swiftdialog_api_url/tags/$$swiftdialog_bigsur_tag" --header "Authorization: Bearer $$github_token" --header "X-GitHub-Api-Version: 2022-11-28" | /usr/bin/plutil -extract 'assets.0.browser_download_url' raw -) ;\
	echo "## Downloading swiftDialog from $$swiftdialog_bigsur_url" ;\
	curl -L "$$swiftdialog_bigsur_url" -o "/private/tmp/swiftDialog.pkg" ;\
	echo "## Downloaded swiftDialog $$swiftdialog_bigsur_tag"
	echo "## Extracting Dialog.app from swiftDialog pkg" ;\
	pkgutil --expand "/private/tmp/swiftDialog.pkg" "/private/tmp/swiftDialog_expanded" ;\
	mkdir -p "/private/tmp/swiftDialog_payload" ;\
	cd "/private/tmp/swiftDialog_payload" && cat "/private/tmp/swiftDialog_expanded/tmp-package.pkg/Payload" | gunzip -dc | cpio -i ;\
	cp -r "/private/tmp/swiftDialog_payload/Library/Application Support/Dialog/Dialog.app" "$(PKG_SCRIPTS)/Dialog-bigsur.app" ;\
	rm -rf "/private/tmp/swiftDialog_expanded" "/private/tmp/swiftDialog_payload" "/private/tmp/swiftDialog.pkg"
	@echo
	mist_tag=$$(awk -F '=' '/mist_tag_required=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Downloading mist-cli $$mist_tag" ;\
	github_token=$$(cat $(GITHUB_TOKEN_FILE)) ;\
	mist_api_url="https://api.github.com/repos/ninxsoft/mist-cli/releases" ;\
	mist_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$mist_api_url/tags/$$mist_tag" --header "Authorization: Bearer $$github_token" --header "X-GitHub-Api-Version: 2022-11-28" | awk -F '"' '/browser_download_url/ { print $$4; exit }') ;\
	curl -L "$$mist_url" -o "$(PKG_SCRIPTS)/mist-cli.pkg" ;\
	echo "## Downloaded mist-cli $$mist_tag"

	@echo
	echo "## Downloading jq arm64" ;\
	github_token=$$(cat $(GITHUB_TOKEN_FILE)) ;\
	jq_api_url="https://api.github.com/repos/jqlang/jq/releases/latest" ;\
    jq_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$jq_api_url" --header "Authorization: Bearer $$github_token" --header "X-GitHub-Api-Version: 2022-11-28" | /usr/bin/jq -r '.assets[] | select(.name == "jq-macos-arm64") | .browser_download_url') ;\
	curl -L "$$jq_url" -o "$(PKG_SCRIPTS)/jq-arm64" ;\
	echo "## Downloaded jq (arm64)"

	@echo
	echo "## Downloading jq amd64" ;\
	github_token=$$(cat $(GITHUB_TOKEN_FILE)) ;\
	jq_api_url="https://api.github.com/repos/jqlang/jq/releases/latest" ;\
    jq_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$jq_api_url" --header "Authorization: Bearer $$github_token" --header "X-GitHub-Api-Version: 2022-11-28" | /usr/bin/jq -r '.assets[] | select(.name == "jq-macos-amd64") | .browser_download_url') ;\
	curl -L "$$jq_url" -o "$(PKG_SCRIPTS)/jq-amd64" ;\
	echo "## Downloaded jq (amd64)"

	@echo
	@echo "## Making package in '$(PKG_ROOT)' directory"
	pkgbuild --analyze --root "$(PKG_ROOT)" "$(PKG_BUILD)/erase-install-component.plist"
	@component_plist="$(PKG_BUILD)/erase-install-component.plist" ;\
	/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$$component_plist" >/dev/null 2>&1 || \
	/usr/libexec/PlistBuddy -c 'Add :0:BundleIsRelocatable bool false' "$$component_plist" >/dev/null 2>&1 || { \
		/usr/libexec/PlistBuddy -c 'Add :0 dict' "$$component_plist" >/dev/null 2>&1 ; \
		/usr/libexec/PlistBuddy -c 'Add :0:BundleIsRelocatable bool false' "$$component_plist" ; \
	}
	pkgbuild --root "$(PKG_ROOT)" --identifier "com.github.grahampugh.erase-install.pkg" --version "$(PKG_VERSION)" --install-location "/" --component-plist "$(PKG_BUILD)/erase-install-component.plist" --scripts "$(PKG_SCRIPTS)" --sign "$(SIGN_ID_PKG)" "$(PKG_FILE)"
	open $(PKG_BUILD)

.PHONY : release release-only publish-release
release: build publish-release

release-only: publish-release

publish-release:
	@echo
	@echo "## Creating pre-release $(RELEASE_TAG) with package $(PKG_FILE)"
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "ERROR: gh command not found. Install GitHub CLI first."; \
		exit 1; \
	fi
	@if [[ ! -f "$(PKG_FILE)" ]]; then \
		echo "ERROR: package not found at $(PKG_FILE)"; \
		exit 1; \
	fi
	@release_notes_file=$$(mktemp "/tmp/erase-install-release-notes.XXXXXX") ;\
	if ! awk -v tag="$(PKG_VERSION)" '\
		$$0 ~ "^## \\[[[:space:]]*" tag "[[:space:]]*\\]" { in_section=1; next } \
		in_section && $$0 ~ "^## \\[" { exit } \
		in_section { print; found=1 } \
		END { if (!found) exit 1 }' "$(CURDIR)/CHANGELOG.md" > "$$release_notes_file"; then \
		echo "ERROR: could not find CHANGELOG section for [$(PKG_VERSION)]"; \
		rm -f "$$release_notes_file"; \
		exit 1; \
	fi ;\
	if [[ -f "$(GITHUB_TOKEN_FILE)" ]]; then \
		export GH_TOKEN=$$(cat "$(GITHUB_TOKEN_FILE)"); \
	fi ;\
	if gh release view "$(RELEASE_TAG)" >/dev/null 2>&1; then \
		echo "## Existing release $(RELEASE_TAG) found. Replacing it..."; \
		gh release delete "$(RELEASE_TAG)" --yes || exit 1; \
	fi ;\
	gh release create "$(RELEASE_TAG)" "$(PKG_FILE)" \
		--title "$(RELEASE_TAG)" \
		--notes-file "$$release_notes_file" \
		--prerelease || { rm -f "$$release_notes_file"; exit 1; } ;\
	rm -f "$$release_notes_file" ;\
	echo "## Pre-release $(RELEASE_TAG) created successfully."

.PHONY : clean
clean :
	@echo "Cleaning up package root"
	rm -Rf "$(PKG_ROOT)/Library/Management/erase-install/"* ||:
	rm $(CURDIR)/pkg/erase-install/build/*.pkg ||:
	rm -Rf $(CURDIR)/pkg/erase-install/scripts/*.pkg ||:
	rm -Rf $(CURDIR)/pkg/erase-install/scripts/*.app ||:
	rm $(CURDIR)/pkg/erase-install/scripts/jq* ||:
	rm -Rf $(CURDIR)/pkg/erase-install/payload ||:
