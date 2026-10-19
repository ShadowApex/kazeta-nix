# Task runner for kazeta-nix. Run `make` or `make help` to list targets.
# Environment overrides: TESTDIR, ARCH, NON_INTERACTIVE, PACKAGE_FILE, PACKAGE.

TESTDIR ?= /tmp/kazeta-test
HOST_ARCH := $(shell uname -m)
ARCH ?= $(HOST_ARCH)
NON_INTERACTIVE ?= false
PACKAGES := $(shell find ./pkgs/by-name -name 'package.nix')
NON_INTERACTIVE_FLAG := $(shell test "$(NON_INTERACTIVE)" = true && echo -y)

.DEFAULT_GOAL := help

.PHONY: help
help: ## List the available targets
	@echo 'Usage: make <target>'
	@echo
	@grep -hE '^[0-9a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-22s %s\n", $$1, $$2}'

.PHONY: default
default: help

.PHONY: update-inputs
update-inputs: ## Update flake inputs with the latest packages
	nix flake update

.PHONY: update-nixpkgs
update-nixpkgs: update-inputs

# Shared setup: a throwaway host flake built from the template, with the
# flake URL pointed at this checkout.
.PHONY: setup-test-flake
setup-test-flake:
	rm -rf $(TESTDIR)
	mkdir -p $(TESTDIR)
	nixos-generate-config --dir $(TESTDIR)
	sed -i 's|^}|  boot.loader.grub.devices = [ "/dev/null" ];\n}|g' \
		$(TESTDIR)/hardware-configuration.nix
	sed 's|kazeta.url =.*|kazeta.url = "path:$(CURDIR)";|g' \
		./templates/host-$(HOST_ARCH)/flake.nix > $(TESTDIR)/flake.nix

.PHONY: update-kazeta-package
update-kazeta-package: ## Update one Kazeta package (PACKAGE_FILE required)
	@test -n "$(PACKAGE_FILE)" || { echo 'error: PACKAGE_FILE is required' >&2; exit 1; }
	nix run --impure 'nixpkgs#nix-update' -- $(NON_INTERACTIVE_FLAG) \
		--flake .#$(notdir $(patsubst %/,%,$(dir $(PACKAGE_FILE))))

.PHONY: update-kazeta-packages
update-kazeta-packages: ## Update every Kazeta package in pkgs/by-name
	for _pkg in $(PACKAGES); do $(MAKE) update-kazeta-package \
		PACKAGE_FILE="$$_pkg" NON_INTERACTIVE="$(NON_INTERACTIVE)" || exit 1; done

.PHONY: test
test: ## Build a test build of the flake OS configuration
	$(MAKE) setup-test-flake
	cd $(TESTDIR) && NIXPKGS_ALLOW_UNFREE=1 nix build --show-trace --impure \
		.#nixosConfigurations.kazeta.config.system.build.toplevel
	rm -f result
	cp -P $(TESTDIR)/result ./

.PHONY: test-format
test-format: ## Check that Nix files are formatted with nixfmt
	nix fmt -- --check .

.PHONY: build-iso
build-iso: ## Build the live Kazeta ISO image (ARCH must be x86_64)
	@test "$(ARCH)" = x86_64 || { echo 'error: ARCH must be x86_64' >&2; exit 1; }
	NIXPKGS_ALLOW_UNFREE=1 nix build --impure \
		.#nixosConfigurations.iso-$(ARCH).config.system.build.isoImage

.PHONY: build-package
build-package: ## Build a single package from the repo (PACKAGE required)
	@test -n "$(PACKAGE)" || { echo 'error: PACKAGE is required' >&2; exit 1; }
	nix build --show-trace .#$(PACKAGE)
