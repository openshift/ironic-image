# Building ironic-image locally

In case there is a need to build ironic-image locally, the user needs to ensure access `oc` binary and the the appropriate image registries.

## Installing oc client

oc client binary may be obtained from [access.redhat.com](https://access.redhat.com/downloads/content/290/ver=4.20/rhel---9/4.20.0/x86_64/product-software)

## Authenticating to CI registry

If login token is obtained from [console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com](https://console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com) (as indicated in [openshift-metal3/devscripts](https://github.com/openshift-metal3/dev-scripts/blob/master/README.md?plain=1#L65), the following steps may be used:

```
oc login --server=https://api.ci.l2s4.p1.openshiftapps.com:6443 --token=<TOKEN>
oc registry login
```

## Building ironic-image

Once the prerequisites are satisfied, the build can be triggered by running `make` or `podman build .` inside the repo directory.

