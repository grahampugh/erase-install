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
	swiftdialog_version=$$(awk -F '=' '/swiftdialog_version_required=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	swiftdialog_tag=$$( awk -F '-' '{print $$1}' <<< "$$swiftdialog_version") ;\
	echo "## Downloading swiftDialog v$$swiftdialog_version" ;\
	swiftdialog_url="https://github.com/bartreardon/swiftDialog/releases/download/v$$swiftdialog_tag/dialog-$$swiftdialog_version.pkg" ;\
	curl -L "$$swiftdialog_url" -o "$(PKG_SCRIPTS)/dialog.pkg"

	@echo
	mist_version=$$(awk -F '=' '/mist_version_required=/ {print $$NF}' $(CURDIR)/erase-install.sh | tr -d '"') ;\
	echo "## Downloading mist-cli v$$mist_version" ;\
	mist_url="https://github.com/ninxsoft/mist-cli/releases/download/v$$mist_version/mist-cli.$$mist_version.pkg" ;\
	curl -L "$$mist_url" -o "$(PKG_SCRIPTS)/mist-cli.pkg"

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
