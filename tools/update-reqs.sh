#!/bin/bash

set -euo pipefail

if [ ${DEBUG:-""} == "True" ]; then
  set -x
fi

REPO=${REPO:-"all"}
BRANCH=${BRANCH:-"master"}

echo $REPO
echo $BRANCH

function check_and_update_hash () {
  case $REPO in
    "all"|"openstack-ironic"|"openstack-ironic-inspector"|"openstack-ironic-lib"|"openstack-sushy")
  
    line=$(grep "$REPO@" requirements.cachito)
    echo $line
    REPO_full=$(echo $line | cut -d "+" -f 2)
    echo $REPO_full
    current_commit_hash=$(echo $REPO_full | cut -d "@" -f 2)
    echo $current_commit_hash
    git_url=$(echo $REPO_full | cut -d "@" -f 1)
    echo $git_url

    last_commit_hash=$(git ls-remote $git_url | grep $BRANCH | cut -f 1)

    echo $last_commit_hash

    if [ $last_commit_hash != $current_commit_hash ]; then
      echo "*****Updating commit hash for $REPO from $current_commit_hash to $last_commit_hash"
      sed -i "s/$current_commit_hash/$last_commit_hash/g" requirements.cachito
    fi
    ;;

    *)
      echo "Operation not supported for $REPO"
    ;;
  esac
}

if [ $REPO == "all" ]; then
  for REPO in "openstack-ironic" "openstack-ironic-inspector" "openstack-ironic-lib" "openstack-sushy"; do
    check_and_update_hash
  done
else
  check_and_update_hash
fi
