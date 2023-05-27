#!/usr/bin/env bats

@test "git server" {
  if [[ "$(kubectl -n  $OPS_NS get pods -o custom-columns=READY:status.containerStatuses[*].ready | grep true | wc -l)" -eq "1" ]]; then
    skip
  fi

  DETIK_CLIENT_NAMESPACE=""

  run kubectl create ns $OPS_NS
  verify "there are 1 ns named '$OPS_NS'"

  DETIK_CLIENT_NAMESPACE=$OPS_NS

  run ssh-keygen -t rsa -N "" -f "$BATS_SUITE_TMPDIR/id_rsa"
  assert_file_exist "$BATS_SUITE_TMPDIR/id_rsa"
  assert_file_exist "$BATS_SUITE_TMPDIR/id_rsa.pub"

  run kubectl create secret -n $OPS_NS generic ssh-key --from-file="$BATS_SUITE_TMPDIR/id_rsa" --from-file="$BATS_SUITE_TMPDIR/id_rsa.pub"
  verify "there is 1 secret named 'ssh-key'"

  run create_kustomization
  assert_file_exist "$BATS_SUITE_TMPDIR/kustomization.yaml"

  run build_gitsrv
  assert_exist "$BATS_SUITE_TMPDIR/deployment.yaml"

  run kubectl apply -n $OPS_NS -f $BATS_SUITE_TMPDIR/deployment.yaml
  assert_success
  try "at most 60 times every 1s " \
    "to find 1 pods named 'gitsrv' " \
    "with 'status' matching 'Pending'"
  run kubectl wait pods -n $OPS_NS -l name=gitsrv --for=condition=ready --timeout=1m
  verify "there are 1 pod named 'gitsrv'"
  verify "there are 1 service named 'gitsrv'"
  verify "'port' is '22' for services named 'gitsrv'"
}

setup() {
  load 'test_helper/common-setup'
  load 'test_helper/ssh'
  load 'test_helper/bats-detik/lib/utils'
  load 'test_helper/bats-detik/lib/detik'
  _common_setup
}

#teardown() {
  #kubectl delete -n $OPS_NS secret ssh-key || :
  #kubectl delete -n $OPS_NS srv gitsrv || :
  #kubectl delete -n $OPS_NS deploy gitsrv
  #kubectl delete -n $OPS_NS ns $OPS_NS || :
#}

create_kustomization() {
  cat <<EOF> $BATS_SUITE_TMPDIR/kustomization.yaml
bases:
  - github.com/fluxcd/gitsrv/deploy
patches:
- target:
    kind: Deployment
    name: gitsrv
  patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: gitsrv
    spec:
      template:
        spec:
          containers:
          - name: git
            env:
              - name: REPO
                value: "gitops.git"
              - name: TAR_URL
                value: "" # disable download
            volumeMounts:
              - name: local-git
                mountPath: /git-server/repos/gitops.git/
          volumes:
            - name: local-git
              hostPath:
                path: /git  # matches kind containerPath:
EOF
}

build_gitsrv() {
  kustomize build $BATS_SUITE_TMPDIR > $BATS_SUITE_TMPDIR/deployment.yaml
}
