#!/usr/bin/env bash

export_private_key() {
  if [[ -z "$OPS_NS" ]]; then
    assert "OPS_NS Not defined"
  fi
  kubectl get secret -n $OPS_NS ssh-key -o jsonpath='{ .data.id_rsa }' | base64 -d > $BATS_SUITE_TMPDIR/id_rsa \
    && chmod 600 $BATS_SUITE_TMPDIR/id_rsa
}

export_public_key() {
  if [[ -z "$OPS_NS" ]]; then
    assert "OPS_NS Not defined"
  fi
  kubectl get secret -n $OPS_NS ssh-key -o jsonpath='{ .data.id_rsa\.pub }' | base64 -d > $BATS_SUITE_TMPDIR/id_rsa.pub \
    && chmod 600 $BATS_SUITE_TMPDIR/id_rsa.pub
}
