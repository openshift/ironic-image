.PHONY: build-ocp

build-ocp:
	podman build -f Dockerfile.ocp

## Post OKD-4.15, only scos images are used
.PHONY: build-okd

build-okd: 
	podman build -f Dockerfile.scos --build-arg EXTRA_PKGS_LIST="" -t ironic-build.okd 

.PHONY: check-reqs

check-reqs:
	./tools/check-requirements.sh

## --------------------------------------
## Release
## --------------------------------------
GO := $(shell type -P go)
# Use GOPROXY environment variable if set
GOPROXY := $(shell $(GO) env GOPROXY)
ifeq ($(GOPROXY),)
GOPROXY := https://proxy.golang.org
endif
export GOPROXY

RELEASE_TAG ?= $(shell git describe --abbrev=0 2>/dev/null)
RELEASE_NOTES_DIR := releasenotes

$(RELEASE_NOTES_DIR):
	mkdir -p $(RELEASE_NOTES_DIR)/

.PHONY: release-notes
release-notes: $(RELEASE_NOTES_DIR) $(RELEASE_NOTES)
	cd hack/tools && $(GO) run release/notes.go  --releaseTag=$(RELEASE_TAG) > $(realpath $(RELEASE_NOTES_DIR))/$(RELEASE_TAG).md
