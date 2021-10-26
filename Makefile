CURDIR := $(shell pwd)
DEPNOTIFY_URL := "https://files.nomad.menu/DEPNotify.zip"
DEPNOTIFY_ZIPPATH := $(CURDIR)/DEPNotify.zip
MUNKIPKG := /usr/local/bin/munkipkg
PKG_ROOT := $(CURDIR)/pkg/erase-install/payload
PKG_BUILD := $(CURDIR)/pkg/erase-install/build
PKG_ROOT_NOPYTHON := $(CURDIR)/pkg/erase-install-nopython/payload
PKG_BUILD_NOPYTHON := $(CURDIR)/pkg/erase-install-nopython/build
PKG_ROOT_DEPNOTIFY := $(CURDIR)/pkg/erase-install-depnotify/payload
PKG_BUILD_DEPNOTIFY := $(CURDIR)/pkg/erase-install-depnotify/build
PKG_VERSION := $(shell defaults read $(CURDIR)/pkg/erase-install/build-info.plist version)
PYTHON_VERSION := 3.9.5
PYTHON_INSTALLER_SCRIPT := $(CURDIR)/../relocatable-python/make_relocatable_python_framework.py
PYTHON_REQUIREMENTS := $(CURDIR)/requirements_python3.txt


all: build

.PHONY : build
build: 
	@echo "Copying erase-install.sh into /Library/Management/erase-install"
	mkdir -p "$(PKG_ROOT)/Library/Management/erase-install"
	cp "$(CURDIR)/erase-install.sh" "$(PKG_ROOT)/Library/Management/erase-install/erase-install.sh"
	chmod 755 "$(PKG_ROOT)/Library/Management/erase-install/erase-install.sh"

	@echo "Copying installinstallmacos.py into /Library/Management/erase-install"
	cp "$(CURDIR)/../macadmin-scripts/installinstallmacos.py" "$(PKG_ROOT)/Library/Management/erase-install/installinstallmacos.py"

	@echo "Installing Python into /Library/Management/erase-install"
	"$(PYTHON_INSTALLER_SCRIPT)" --destination "$(PKG_ROOT)/Library/Management/erase-install/" --python-version=$(PYTHON_VERSION) --pip-requirements="$(PYTHON_REQUIREMENTS)"

	@echo "Making package in $(PKG_BUILD) directory"
	cd $(CURDIR)/pkg && $(MUNKIPKG) erase-install
	open $(PKG_BUILD)

.PHONY : nopython
nopython: 
	@echo "Copying erase-install.sh into /Library/Management/erase-install"
	mkdir -p "$(PKG_ROOT_NOPYTHON)/Library/Management/erase-install"
	cp "$(CURDIR)/erase-install.sh" "$(PKG_ROOT_NOPYTHON)/Library/Management/erase-install/erase-install.sh"
	chmod 755 "$(PKG_ROOT_NOPYTHON)/Library/Management/erase-install/erase-install.sh"

	@echo "Copying installinstallmacos.py into /Library/Management/erase-install"
	cp "$(CURDIR)/../macadmin-scripts/installinstallmacos.py" "$(PKG_ROOT_NOPYTHON)/Library/Management/erase-install/installinstallmacos.py"

	@echo "Making package in $(PKG_BUILD_NOPYTHON) directory"
	cd $(CURDIR)/pkg && $(MUNKIPKG) erase-install-nopython
	open $(PKG_BUILD_NOPYTHON)

.PHONY : depnotify
depnotify: 
	@echo "Copying erase-install.sh into /Library/Management/erase-install"
	mkdir -p "$(PKG_ROOT_DEPNOTIFY)/Library/Management/erase-install"
	cp "$(CURDIR)/erase-install.sh" "$(PKG_ROOT_DEPNOTIFY)/Library/Management/erase-install/erase-install.sh"
	chmod 755 "$(PKG_ROOT_DEPNOTIFY)/Library/Management/erase-install/erase-install.sh"

	@echo "Copying installinstallmacos.py into /Library/Management/erase-install"
	cp "$(CURDIR)/../macadmin-scripts/installinstallmacos.py" "$(PKG_ROOT_DEPNOTIFY)/Library/Management/erase-install/installinstallmacos.py"

	@echo "Installing Python into /Library/Management/erase-install"
	"$(PYTHON_INSTALLER_SCRIPT)" --destination "$(PKG_ROOT_DEPNOTIFY)/Library/Management/erase-install/" --python-version=$(PYTHON_VERSION) --pip-requirements="$(PYTHON_REQUIREMENTS)"

	@echo "Downloading and extracting DEPNotify.app into /Applications/Utilities"
	mkdir -p "$(PKG_ROOT_DEPNOTIFY)/Applications/Utilities"
	curl -L "$(DEPNOTIFY_URL)" -o "$(DEPNOTIFY_ZIPPATH)"
	unzip -o "$(DEPNOTIFY_ZIPPATH)" -d "$(PKG_ROOT_DEPNOTIFY)/Applications/Utilities"
	chmod -R 755 "$(PKG_ROOT_DEPNOTIFY)/Applications/Utilities"

	@echo "Making package in $(PKG_BUILD_DEPNOTIFY) directory"
	cd $(CURDIR)/pkg && $(MUNKIPKG) erase-install-depnotify
	open $(PKG_BUILD_DEPNOTIFY)

	rm -Rf "$(PKG_ROOT_DEPNOTIFY)/Applications/Utilities/__MACOSX"


.PHONY : clean
clean :
	@echo "Cleaning up package root"
	rm -Rf "$(PKG_ROOT)/Library/Management/erase-install/"* ||:
	rm -Rf "$(PKG_ROOT)/Library/Management/erase-install/tests" ||:
	rm -Rf "$(PKG_ROOT_NOPYTHON)/Library/Management/erase-install/"* ||:
	rm -Rf "$(PKG_ROOT_NOPYTHON)/Library/Management/erase-install/tests" ||:
	rm -Rf "$(PKG_ROOT_DEPNOTIFY)/Library/Management/erase-install/"* ||:
	rm -Rf "$(PKG_ROOT_DEPNOTIFY)/Library/Management/erase-install/tests" ||:
	rm $(CURDIR)/pkg/erase-install/build/*.pkg ||:
	rm $(CURDIR)/pkg/erase-install-nopython/build/*.pkg ||:
	rm $(CURDIR)/pkg/erase-install-depnotify/build/*.pkg ||:
