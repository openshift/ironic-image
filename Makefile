.PHONY: build-ocp

build-ocp:
	podman build -f Dockerfile.ocp

## Post OKD-4.15, only scos images are used
.PHONY: build-okd

build-ocp: 
	podman build -f Dockerfile.scos

.PHONY: check-reqs

check-reqs:
	./tools/check-requirements.sh

