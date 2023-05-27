#!/usr/bin/env bats

@test "install flux" {
  run flux check --pre
  assert_success

  run flux install
  assert_success

  run flux check
  assert_success
}

@test "create secret on client" {
  if [[ "$(kubectl -n $CLIENT_NS get pods -o custom-columns=READY:status.containerStatuses[*].ready | grep true | wc -l)" -eq "1" ]]; then
    skip
  fi

  if [[ ! -f $BATS_SUITE_TMPDIR"/kubeconfig" ]]; then
    skip
  fi

  DETIK_CLIENT_NAMESPACE=""

  run kubectl create ns $CLIENT_NS
  verify "there are 1 ns named '$CLIENT_NS'"

  DETIK_CLIENT_NAMESPACE=$OPS_NS
  verify "there is 1 secret named 'ssh-key'"

  run export_private_key
  assert_success

  run export_public_key
  assert_success

  DETIK_CLIENT_NAMESPACE=$CLIENT_NS
  run kubectl create secret -n $CLIENT_NS generic ssh-key --from-file="$BATS_SUITE_TMPDIR/id_rsa" --from-file="$BATS_SUITE_TMPDIR/id_rsa.pub"
  verify "there is 1 secret named 'ssh-key'"

  DETIK_CLIENT_NAMESPACE=$CLIENT_NS

  run create_client_configmap
  assert_file_exists "$BATS_TEST_TMPDIR"/setup.sh

  run kubectl create secret -n $CLIENT_NS generic support-files  --from-file="$BATS_SUITE_TMPDIR/kubeconfig" --from-file="$BATS_TEST_TMPDIR/setup.sh"
  verify "there is 1 secret named 'support-files'"
  run create_client_deploy
  assert_file_exist "$BATS_TEST_TMPDIR/deployment.yaml"

  run kubectl apply -n $CLIENT_NS -f $BATS_TEST_TMPDIR/deployment.yaml
  assert_success
  try "at most 60 times every 1s " \
    "to find 1 pods named 'deploy' " \
    "with 'status' matching 'Pending'"
  run kubectl wait pods -n "$CLIENT_NS" -l name='deploy' --for=condition=ready --timeout=10m
  assert_success
  verify "there are 1 pods named 'deploy'"
}

@test "create gitrepository" {
  DETIK_CLIENT_NAMESPACE=flux-system

  run create_gitrepository
  assert_exist "$BATS_SUITE_TMPDIR/git_repository.yaml"

  run kubectl apply -f $BATS_SUITE_TMPDIR/git_repository.yaml
  assert_success
  run kubectl -n flux-system wait gitrepository/flux-system --for=condition=ready --timeout=1m
  assert_success
  verify "there is 1 gitrepository named 'flux-system'"
}

@test "cluster reconciliation" {
  DETIK_CLIENT_NAMESPACE=flux-system

  run flux create kustomization flux-system --source=GitRepository/flux-system --path=./clusters/$CLUSTER
  assert_success
  run kubectl -n flux-system wait kustomization/flux-system --for=condition=ready --timeout=1m
  assert_success
  verify "there is 1 kustomization named 'flux-system'"
  #verify "'.status.conditions[?(@.type==\"Ready\")].status' is 'True' for kustomization named 'flux-system'"
}

setup() {
  load 'test_helper/common-setup'
  load 'test_helper/ssh'
  load 'test_helper/bats-detik/lib/utils'
  load 'test_helper/bats-detik/lib/detik'
  _common_setup
  DETIK_CLIENT_NAMESPACE="flux-system"
}

#teardown() {
  #flux uninstall || :
#}

create_gitrepository() {
  cat <<EOF> $BATS_SUITE_TMPDIR/git_repository.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 15m
  ref:
    branch: $BRANCH
  url: $GIT_REPO
  secretRef:
    name: flux-system-auth
  ignore: |
    /clusters/$CLUSTER/flux-system/
EOF
}

create_client_configmap() {
  cat <<EOF> $BATS_TEST_TMPDIR/setup.sh
#!/bin/bash
set -e
pacman -Syu --noconfirm \
  && pacman -S --noconfirm --needed vim git openssh base-devel go kubectl \
  && (useradd -m deploy || :) \
  && usermod -G wheel deploy \
  && mkdir -p /home/deploy/.ssh \
  && cp -ar /git-server/keys/..data/* /home/deploy/.ssh/ \
  && chown -R deploy:deploy /home/deploy/.ssh \
  && su -c 'git clone $GIT_REPO /home/deploy/githops' deploy \
  && su -c 'git config --global user.email deploy@gitops.local' deploy \
  && su -c 'git config --global user.name deploy' deploy \
  && su -c 'git clone https://aur.archlinux.org/yay-bin.git /home/deploy/yay-bin' deploy \
  && su -c 'cd /home/deploy/yay-bin && makepkg' deploy \
  && echo 'deploy ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/deploy \
  && echo '%wheel ALL=(ALL:ALL) ALL' >> /etc/sudoers.d/wheel \
  && echo 'deploy:deploy' | chpasswd \
  && pacman -U --noconfirm --needed /home/deploy/yay-bin/*.zst \
  && su -c 'yay -Sw --noconfirm --needed flux-bin' deploy \
  && su -c 'cd /home/deploy/.cache/yay/flux-bin && makepkg' deploy \
  && pacman -U --noconfirm --needed /home/deploy/.cache/yay/flux-bin/*.zst \
  && mkdir -p /home/deploy/.kube \
  && cp /support/kubeconfig /home/deploy/.kube/config \
  && chmod 600 /home/deploy/.kube/config \
  && chown -R deploy:deploy /home/deploy/.kube/ \
  && su -c 'flux create secret git flux-system-auth --url=$GIT_REPO --private-key-file=/home/deploy/.ssh/id_rsa' deploy
rm -rf /home/deploy/yay-bin
while true; do sleep 2; done
EOF
}

create_client_deploy() {
  cat <<EOF> $BATS_TEST_TMPDIR/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    name: deploy
  name: deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      name: deploy
  template:
    metadata:
      labels:
        name: deploy
    spec:
      containers:
      - image: archlinux
        name: deploy
        command: [ "/support/setup.sh" ]
        env:
          - name: GIT_SSH_COMMAND
            value: "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
        readinessProbe:
          exec:
            command:
              - su
              - -c
              - "kubectl get secrets -n flux-system flux-system-auth -o name"
              - deploy
        volumeMounts:
        - mountPath: /git-server/keys
          name: ssh-key
        - mountPath: /support
          name: support-files
      volumes:
      - name: ssh-key
        secret:
          secretName: ssh-key
          defaultMode: 384 # Octal: 600 Decimal 384
      - name: support-files
        secret:
          secretName: support-files
          defaultMode: 448 # Octal: 600 Decimal 700
EOF
}
