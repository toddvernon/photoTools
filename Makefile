PROJECT = PhotoToolsSwift
SCHEME = PhotoToolsSwift
INSTALL_DIR = /usr/local/bin
TOOLS = photocopy photorenumber photodedup photocheck photocheckexif videocheckqt
DERIVED_DATA = $(HOME)/Library/Developer/Xcode/DerivedData

.PHONY: build release clean install

build:
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration Debug build

release:
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) -configuration Release build

clean:
	xcodebuild -project $(PROJECT).xcodeproj -scheme $(SCHEME) clean

install: release
	$(eval BINARY := $(shell find $(DERIVED_DATA) -name $(PROJECT) -type f -perm +111 -path "*/Build/Products/Release/*" 2>/dev/null | head -1))
	@if [ -z "$(BINARY)" ]; then echo "error: binary not found"; exit 1; fi
	@echo "Installing $(BINARY) to $(INSTALL_DIR)/"
	sudo cp "$(BINARY)" $(INSTALL_DIR)/$(PROJECT)
	@for tool in $(TOOLS); do \
		echo "Creating symlink: $$tool -> $(PROJECT)"; \
		sudo ln -sf $(INSTALL_DIR)/$(PROJECT) $(INSTALL_DIR)/$$tool; \
	done
	@echo "Done."
