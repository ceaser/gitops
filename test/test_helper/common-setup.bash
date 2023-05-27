#!/usr/bin/env bash

_common_setup() {
    load 'test_helper/bats-support/load'
    load 'test_helper/bats-assert/load'
    load 'test_helper/bats-file/load'
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    DETIK_CLIENT_NAME="kubectl"
    if [[ -z "$CLUSTER" ]]; then CLUSTER="my-cluster"; fi
    if [[ -z "$OPS_NS" ]]; then OPS_NS="ops"; fi
    if [[ -z "$CLIENT_NS" ]]; then CLIENT_NS="client"; fi
    if [[ -z "$GIT_REPO" ]]; then GIT_REPO="ssh://git@gitsrv.$OPS_NS.svc.cluster.local/git-server/repos/gitops.git"; fi
    if [[ -z "$BRANCH" ]]; then BRANCH="test"; fi
    if [[ -z "$KIND_IMAGE" ]]; then KIND_IMAGE="kindest/node:v1.23.17@sha256:e5fd1d9cd7a9a50939f9c005684df5a6d145e8d695e78463637b79464292e66c"; fi
}
