PREFIX ?= $(HOME)/.local
BINDIR := $(PREFIX)/bin
SCRIPT := rotate

.PHONY: install uninstall test lint help

help:
	@echo "targets: install  uninstall  test  lint"
	@echo "install dir: $(BINDIR)  (override with PREFIX=/usr/local)"

install:
	@mkdir -p "$(BINDIR)"
	@install -m 755 "$(SCRIPT)" "$(BINDIR)/$(SCRIPT)"
	@echo "installed $(BINDIR)/$(SCRIPT)"
	@case ":$$PATH:" in *":$(BINDIR):"*) : ;; *) echo "note: $(BINDIR) is not on your PATH" ;; esac

uninstall:
	@rm -f "$(BINDIR)/$(SCRIPT)"
	@echo "removed $(BINDIR)/$(SCRIPT)"

lint:
	shellcheck "$(SCRIPT)" install.sh

test:
	bats tests/
