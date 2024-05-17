SHELL := /bin/bash
CURDIR != pwd
MUNKIPKG := /usr/local/bin/munkipkg
PKG_ROOT := $(CURDIR)/pkg/erase-install/payload
PKG_SCRIPTS := $(CURDIR)/pkg/erase-install/scripts
PKG_BUILD := $(CURDIR)/pkg/erase-install/build

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
	swiftdialog_tag=$$(awk -F '=' '/swiftdialog_tag_required=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Downloading swiftDialog $$swiftdialog_tag" ;\
	swiftdialog_api_url="https://api.github.com/repos/swiftDialog/swiftDialog/releases" ;\
	swiftdialog_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$swiftdialog_api_url/tags/$$swiftdialog_tag" | awk -F '"' '/browser_download_url/ { print $$4; exit }') ;\
	curl -L "$$swiftdialog_url" -o "$(PKG_SCRIPTS)/dialog.pkg" ;\
	echo "## Downloaded swiftDialog $$swiftdialog_tag"

	@echo
	swiftdialog_bigsur_tag=$$(awk -F '=' '/swiftdialog_bigsur_tag_required=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Downloading swiftDialog $$swiftdialog_bigsur_tag" ;\
	swiftdialog_api_url="https://api.github.com/repos/swiftDialog/swiftDialog/releases" ;\
	swiftdialog_bigsur_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$swiftdialog_api_url/tags/$$swiftdialog_bigsur_tag" | awk -F '"' '/browser_download_url/ { print $$4; exit }') ;\
	curl -L "$$swiftdialog_bigsur_url" -o "$(PKG_SCRIPTS)/dialog.pkg" ;\
	echo "## Downloaded swiftDialog $$swiftdialog_bigsur_tag"

	@echo
	mist_tag=$$(awk -F '=' '/mist_tag_required=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Downloading mist-cli $$mist_tag" ;\
	mist_api_url="https://api.github.com/repos/ninxsoft/mist-cli/releases" ;\
	mist_url=$$(/usr/bin/curl -sL -H "Accept: application/json" "$$mist_api_url/tags/$$mist_tag" | awk -F '"' '/browser_download_url/ { print $$4; exit }') ;\
	curl -L "$$mist_url" -o "$(PKG_SCRIPTS)/mist-cli.pkg" ;\
	echo "## Downloaded mist-cli $$mist_tag"

	@echo
	pkg_version=$$(awk -F '=' '/^version=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Writing version string $$pkg_version to build-info.plist" ;\
	/usr/libexec/PlistBuddy -c "Set :version '$$pkg_version'" $(CURDIR)/pkg/erase-install/build-info.plist

	@echo
	@echo "## Making package in '$(PKG_ROOT)' directory"
	cd $(CURDIR)/pkg && python3 $(MUNKIPKG) erase-install
	open $(PKG_BUILD)

.PHONY : clean
clean :
	@echo "Cleaning up package root"
	rm -Rf "$(PKG_ROOT)/Library/Management/erase-install/"* ||:
	rm $(CURDIR)/pkg/erase-install/build/*.pkg ||:
	rm -Rf $(CURDIR)/pkg/erase-install/payload ||:
