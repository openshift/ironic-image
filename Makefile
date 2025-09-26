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

