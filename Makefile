CURDIR := $(shell pwd)
USER := $(shell whoami)
MISTCLI_URL := "https://github.com/ninxsoft/mist-cli/releases/download/v1.10/mist-cli.1.10.pkg"
SWIFTDIALOG_URL := "https://github.com/bartreardon/swiftDialog/releases/download/v2.1.0/dialog-2.1.0-4148.pkg"
MUNKIPKG := /usr/local/bin/munkipkg
PKG_ROOT := $(CURDIR)/pkg/erase-install/payload
PKG_SCRIPTS := $(CURDIR)/pkg/erase-install/scripts
PKG_BUILD := $(CURDIR)/pkg/erase-install/build
PKG_VERSION := $(shell defaults read $(CURDIR)/pkg/erase-install/build-info.plist version)

all: build

.PHONY : build
build: 
	@echo "Copying erase-install.sh into /Library/Management/erase-install"
	mkdir -p "$(PKG_ROOT)/Library/Management/erase-install"
	cp "$(CURDIR)/erase-install.sh" "$(PKG_ROOT)/Library/Management/erase-install/erase-install.sh"
	chmod 755 "$(PKG_ROOT)/Library/Management/erase-install/erase-install.sh"

	@echo "Downloading swiftDialog"
	mkdir -p "$(PKG_SCRIPTS)"
	curl -L "$(SWIFTDIALOG_URL)" -o "$(PKG_SCRIPTS)/dialog.pkg"

	@echo "Downloading mist-cli"
	mkdir -p "$(PKG_SCRIPTS)"
	curl -L "$(MISTCLI_URL)" -o "$(PKG_SCRIPTS)/mist-cli.pkg"

	@echo "Making package in $(PKG_ROOT) directory"
	cd $(CURDIR)/pkg && python3 $(MUNKIPKG) erase-install
	open $(PKG_BUILD)

.PHONY : clean
clean :
	@echo "Cleaning up package root"
	rm -Rf "$(PKG_ROOT)/Library/Management/erase-install/"* ||:
	rm $(CURDIR)/pkg/erase-install/build/*.pkg ||:
	rm -Rf $(CURDIR)/pkg/erase-install/payload ||:
