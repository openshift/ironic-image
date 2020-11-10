#!/usr/bin/bash

set -euxo pipefail

SOURCE_DIR=/var/tmp/SOURCES
mkdir -p ${SOURCE_DIR}

dnf install -y rpm-build

for PROJECT in $(ls sources); do
    cp sources/${PROJECT}/* ${SOURCE_DIR}
    source ${SOURCE_DIR}/${PROJECT}_release
    dnf builddep -y "specs/openshift-${PROJECT}.spec"
    rpmbuild -ba -D "_version $VERSION" \
        -D "_build_date_time $BUILD_DATE_TIME" \
        -D "_release $RELEASE" \
        -D "_topdir /var/tmp/" "specs/openshift-${PROJECT}.spec"
done

#debug steps, can be removed in final version
dnf install -y tree
ls -la /var/tmp
tree /var/tmp
