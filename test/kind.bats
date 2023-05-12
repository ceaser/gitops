#!/usr/bin/env bats

@test "kind cluster" {
  if [[ "$(kind get clusters | grep $CLUSTER | wc -l)" -eq 1 ]]; then
    skip
  fi
  run create_git_repo
  assert_dir_exists "$GIT_DATA_DIR/.git"
  run create_config
  assert_file_exists "$BATS_SUITE_TMPDIR/kind-config.yaml"
  run kind create cluster --config $BATS_SUITE_TMPDIR/kind-config.yaml --name $CLUSTER
  assert_equal "$(kind get clusters | grep $CLUSTER | wc -l)" "1"
}

@test "kubeconfig" {
  run create_kubeconfig
  assert_success
  assert_file_exists "$BATS_SUITE_TMPDIR/kubeconfig"
}

setup() {
  load 'test_helper/common-setup'
  _common_setup
  DATA_DIR=$PROJECT_ROOT/test/.data
  GIT_DATA_DIR=$DATA_DIR/kind/git
}

create_git_repo() {
  if [[ ! -d $GIT_DATA_DIR/.git ]]; then
    mkdir -p "$GIT_DATA_DIR"
    cp -r "$PROJECT_ROOT/.git/" "$GIT_DATA_DIR"
  fi
}

#teardown() {
  #kind delete cluster --name $CLUSTER || :
#}

create_config() {
  cat <<EOF> $BATS_SUITE_TMPDIR/kind-config.yaml
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
  - role: control-plane
    image: $KIND_IMAGE
    extraMounts:
      - hostPath: $PROJECT_ROOT/test/.data/kind/git
        containerPath: /git
  #- role: worker
  #  image: kindest/node:v1.23.17@sha256:e5fd1d9cd7a9a50939f9c005684df5a6d145e8d695e78463637b79464292e66c
  #- role: worker
  #  image: kindest/node:v1.23.17@sha256:e5fd1d9cd7a9a50939f9c005684df5a6d145e8d695e78463637b79464292e66c
  #- role: worker
  #  image: kindest/node:v1.23.17@sha256:e5fd1d9cd7a9a50939f9c005684df5a6d145e8d695e78463637b79464292e66c
EOF
}

create_kubeconfig() {
  kind get kubeconfig --name $CLUSTER --internal > "$BATS_SUITE_TMPDIR/kubeconfig"
}
