CURDIR := $(shell pwd)
MUNKIPKG := /usr/local/bin/munkipkg
PKG_ROOT := $(CURDIR)/pkg/erase-install/payload
PKG_BUILD := $(CURDIR)/pkg/erase-install/build
PKG_VERSION := $(shell defaults read $(CURDIR)/pkg/erase-install/build-info.plist version)

objects = $(PKG_ROOT)/Library/Management/erase-install/erase-install.sh \
	$(PKG_ROOT)/Library/Management/erase-install/installinstallmacos.py


default : $(PKG_BUILD)/erase-install-$(PKG_VERSION).pkg
	@echo "Building erase-install pkg"


$(PKG_BUILD)/erase-install-$(PKG_VERSION).pkg: $(objects)
	cd $(CURDIR)/pkg && $(MUNKIPKG) erase-install
	open $(CURDIR)/pkg/erase-install/build


$(PKG_ROOT)/Library/Management/erase-install/erase-install.sh:
	@echo "Copying erase-install into /Library/Management/erase-install"
	mkdir -p "$(PKG_ROOT)/Library/Management/erase-install"
	cp "$(CURDIR)/erase-install.sh" "$(PKG_ROOT)/Library/Management/erase-install/erase-install.sh"
	chmod 755 "$(PKG_ROOT)/Library/Management/erase-install/erase-install.sh"


$(PKG_ROOT)/Library/Management/erase-install/installinstallmacos.py:
	@echo "Copying installinstallmacos.py into /Library/Management/erase-install"
	cp "$(CURDIR)/../macadmin-scripts/installinstallmacos.py" "$(PKG_ROOT)/Library/Management/erase-install/installinstallmacos.py"

.PHONY : clean
clean :
	@echo "Cleaning up package root"
	rm "$(PKG_ROOT)/Library/Management/erase-install/"* ||:
	rm $(CURDIR)/pkg/erase-install/build/*.pkg ||:
