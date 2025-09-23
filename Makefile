SHELL := /bin/bash
CURDIR != pwd
PKG_ROOT := $(CURDIR)/pkg/erase-install/payload
PKG_SCRIPTS := $(CURDIR)/pkg/erase-install/scripts
PKG_BUILD := $(CURDIR)/pkg/erase-install/build
GITHUB_TOKEN_FILE := /Users/Shared/gh_token
PKG_VERSION :=$(shell awk -F '=' '/^version=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"')

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
	swiftdialog_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$swiftdialog_api_url/tags/$$swiftdialog_tag" --header "Authorization: Bearer $$github_token" --header "X-GitHub-Api-Version: 2022-11-28" | /usr/bin/plutil -extract 'assets.1.browser_download_url' raw -) ;\
	echo "## Downloading swiftDialog from $$swiftdialog_url" ;\
	curl -L "$$swiftdialog_url" -o "/private/tmp/swiftDialog.dmg" ;\
	echo "## Downloaded swiftDialog $$swiftdialog_tag" ;\
	hdiutil attach -quiet -noverify -nobrowse "/private/tmp/swiftDialog.dmg" ;\
	cp -r /Volumes/Dialog/Dialog.app "$(PKG_ROOT)/Library/Management/erase-install/Dialog.app"

	@echo
	swiftdialog_bigsur_tag=$$(awk -F '=' '/swiftdialog_bigsur_tag_required="v/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Downloading swiftDialog $$swiftdialog_bigsur_tag" ;\
	github_token=$$(cat $(GITHUB_TOKEN_FILE)) ;\
	swiftdialog_api_url="https://api.github.com/repos/swiftDialog/swiftDialog/releases" ;\
	swiftdialog_bigsur_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$swiftdialog_api_url/tags/$$swiftdialog_bigsur_tag" --header "Authorization: Bearer $$github_token" --header "X-GitHub-Api-Version: 2022-11-28" | /usr/bin/plutil -extract 'assets.0.browser_download_url' raw -) ;\
	echo "## Downloading swiftDialog from $$swiftdialog_bigsur_url" ;\
	curl -L "$$swiftdialog_bigsur_url" -o "$(PKG_SCRIPTS)/swiftDialog-bigsur.pkg" ;\
	echo "## Downloaded swiftDialog $$swiftdialog_bigsur_tag"

	@echo
	mist_tag=$$(awk -F '=' '/mist_tag_required=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Downloading mist-cli $$mist_tag" ;\
	github_token=$$(cat $(GITHUB_TOKEN_FILE)) ;\
	mist_api_url="https://api.github.com/repos/ninxsoft/mist-cli/releases" ;\
	mist_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$mist_api_url/tags/$$mist_tag" --header "Authorization: Bearer $$github_token" --header "X-GitHub-Api-Version: 2022-11-28" | awk -F '"' '/browser_download_url/ { print $$4; exit }') ;\
	curl -L "$$mist_url" -o "$(PKG_SCRIPTS)/mist-cli.pkg" ;\
	echo "## Downloaded mist-cli $$mist_tag"

	@echo
	@echo "## Making package in '$(PKG_ROOT)' directory"
	pkgbuild --analyze --root "$(PKG_ROOT)" "$(PKG_BUILD)/erase-install-component.plist"
	/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable boolean false' "$(PKG_BUILD)/erase-install-component.plist"
	pkgbuild --root "$(PKG_ROOT)" --identifier "com.github.grahampugh.erase-install.pkg" --version "$(PKG_VERSION)" --install-location "/" --component-plist "$(PKG_BUILD)/erase-install-component.plist" --scripts "$(PKG_SCRIPTS)" "$(PKG_BUILD)/erase-install-$(PKG_VERSION).pkg"
	open $(PKG_BUILD)

.PHONY : clean
clean :
	@echo "Cleaning up package root"
	rm -Rf "$(PKG_ROOT)/Library/Management/erase-install/"* ||:
	rm $(CURDIR)/pkg/erase-install/build/*.pkg ||:
	rm -Rf $(CURDIR)/pkg/erase-install/scripts/*.pkg ||:
	rm -Rf $(CURDIR)/pkg/erase-install/payload ||:
