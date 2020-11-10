#!/usr/bin/bash

set -euxo pipefail

PROJECT=$1
COMMIT=$2

if [ -d "$PROJECT" ]; then
while true; do
    read -p "A repo named $PROJECT already exist, do you want to download it again?" yn
    case $yn in
        [Yy]* )
            rm -fr $PROJECT
            git clone "https://opendev.org/openstack/${PROJECT}"
            cd "$PROJECT"
            break;;
        [Nn]* )
            echo "Re-using same repo"
            cd "$PROJECT"
            break;;
        * ) echo "Please answer yes or no.";;
    esac
done
else
    git clone "https://opendev.org/openstack/${PROJECT}"
    cd "$PROJECT"
fi

git checkout $COMMIT
VERSION=$(python3 setup.py --version)
BUILD_DATE_TIME=$(date '+%Y%m%d%H%M%S%3N')
RELEASE=$(git rev-parse --short HEAD)

python3 setup.py egg_info -b ".${BUILD_DATE_TIME}.${RELEASE}" build sdist

cd -

rm -f sources/${PROJECT}/*.tar.gz
cp ${PROJECT}/dist/${PROJECT}-${VERSION}.${BUILD_DATE_TIME}.${RELEASE}.tar.gz sources/${PROJECT}
cat <<EOF > "sources/${PROJECT}/${PROJECT}_release"
VERSION=$VERSION
BUILD_DATE_TIME=$BUILD_DATE_TIME
RELEASE=$RELEASE
EOF

echo "Run git add, git commit and git push to upload the new version"
