#!/usr/bin/env bats

create_mock_bin() {
  local command_name="$1"
  local mock_bin
  mock_bin=$(mock_create)
  ln -sf "$mock_bin" "$DATA_DIR/bin/$command_name"
  echo "$mock_bin"
}

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  load 'test_helper/bats-file/load'
  load 'test_helper/common-setup'
  load 'test_helper/bats-mock/load'
  _common_setup
  RUN_ROOT=$PROJECT_ROOT
  DATA_DIR=$RUN_ROOT/test/.testdata
  OPS_NS="test-ops"
  CLIENT_NS="test-client"
  GIT_REPO="ssh://test@test.local/test/test/test.git"
  BRANCH="not-a-test"
  CLUSTER="test-cluster"
  mkdir -p "$DATA_DIR/bin"
  PATH="$DATA_DIR/bin:$PATH"
  kind_bin=$(create_mock_bin "kind")
}

teardown() {
  /bin/rm -rf "$DATA_DIR" # Use full path to avoid rm functions
}

run_script() {
  #echo "Debug: $@" >> /tmp/output.txt
  #echo "RUN_ROOT: $RUN_ROOT" >> /tmp/output.txt
  #echo "DATA_DIR: $DATA_DIR" >> /tmp/output.txt
  #echo "OPS_NS: $OPS_NS" >> /tmp/output.txt
  #echo "CLIENT_NS: $CLIENT_NS" >> /tmp/output.txt
  #echo "GIT_REPO: $GIT_REPO" >> /tmp/output.txt
  #echo "BRANCH: $BRANCH" >> /tmp/output.txt
  #echo "REGION: $REGION" >> /tmp/output.txt

  ## 5 is the first available file descriptor
  #exec 5>output.log

  # Redirect both stdout and stderr to the custom file descriptor
  source $RUN_ROOT/test/run
  "$@"
  #"$@" 1> >(tee -a >&5) 2> >(tee -a >&5 >&2)

  #echo "" >> /tmp/output.txt
  #echo "" >> /tmp.output.txt
  ## Close the custom file descriptor
  #exec 5>&-
}

@test "green outputs colored text" {
  run run_script green "This is a test"
  assert_output --partial "This is a test"
}

@test "red outputs colored text" {
  run run_script red "This is a test"
  assert_output --partial "This is a test"
}

@test "verify_deps exits with error if a dependency is missing" {
  run run_script verify_deps
  if [ $status -eq 2 ]; then
    assert_output --partial "is missing"
  else
    assert_success
  fi
}

@test "create_git_repository first run creates a git repository in the gitsrv directory with all the changes in the current directory" {
  tmp_dir="$DATA_DIR/run/tmp/git"
  git_dir="$DATA_DIR/kind/git/.git"
  touch testfile
  run run_script create_git_repository
  assert_success
  assert_dir_exist $tmp_dir
  assert_regex "$(cd $tmp_dir && git remote -v)" "$git_dir"
  assert_file_exist $tmp_dir/testfile
  assert_dir_exist $tmp_dir/clusters/$CLUSTER
  assert_file_exist $tmp_dir/clusters/$CLUSTER/.keep
  assert_equal "$(cd $tmp_dir && git rev-parse --abbrev-ref HEAD)" "${BRANCH}"
  assert_not_equal $(git rev-parse HEAD) $(cd $tmp_dir && git rev-parse HEAD)
  assert_equal "$(cd $(dirname $git_dir) && git rev-parse HEAD)" "$(cd $tmp_dir && git rev-parse HEAD)"
  /bin/rm testfile
}

@test "create_git_repository called twice should not error" {
  tmp_dir="$DATA_DIR/run/tmp/git"
  git_dir="$DATA_DIR/kind/git/.git"
  touch testfile
  run run_script create_git_repository
  assert_success
  touch anothertestfile
  run run_script create_git_repository
  assert_success
  refute_output --partial "fatal:"
  refute_output --partial "Permission denied"
  assert_regex "$(cd $(dirname $git_dir) && git show --name-only HEAD)" "anothertestfile"
  assert_equal "$(cd $(dirname $git_dir) && git rev-parse HEAD)" "$(cd $tmp_dir && git rev-parse HEAD)"
  /bin/rm testfile
  /bin/rm anothertestfile
}

@test "create_git_repository called twice should call sudo if rm returns a error" {
  rm_bin=$(create_mock_bin "rm")
  mock_set_status "${rm_bin}" 1
  sudo_bin=$(create_mock_bin "sudo")
  tmp_dir="$DATA_DIR/run/tmp/git"
  git_dir="$DATA_DIR/kind/git/.git"
  touch testfile
  run run_script create_git_repository
  assert_success
  run run_script create_git_repository
  assert_success
  assert_equal "$(mock_get_call_num ${rm_bin})" 1
  assert_equal "$(mock_get_call_user ${rm_bin} 1)" "$(whoami)"
  assert_equal "$(mock_get_call_num ${sudo_bin})" 1
  assert_equal "$(mock_get_call_args "${sudo_bin}" 1)" "bash -c rm -rf $git_dir && cp -r $tmp_dir/.git $(dirname $git_dir) && chown -R 1000:1000 $git_dir"
  refute_output --partial "fatal:"
  refute_output --partial "Permission denied"
  /bin/rm testfile
}

@test "clean deletes kind clusters and data directory" {
  mkdir -p "$DATA_DIR"
  touch "$DATA_DIR/testfile"
  mock_set_output "${kind_bin}" "test-cluster1\ntest-cluster2" 1
  run run_script clean
  assert_success
  assert_equal "$(mock_get_call_num ${kind_bin})" 3
  assert_regex "$(mock_get_call_args ${kind_bin} 1)" "get clusters"
  assert_regex "$(mock_get_call_args ${kind_bin} 2)" "delete cluster --name test-cluster1"
  assert_regex "$(mock_get_call_args ${kind_bin} 3)" "delete cluster --name test-cluster2"
  assert_file_not_exist "$DATA_DIR/testfile"
}

@test "clean calls sudo if rm returns error" {
  rm_bin=$(create_mock_bin "rm")
  sudo_bin=$(create_mock_bin "sudo")
  mock_set_status "${rm_bin}" 1
  run run_script clean
  assert_success
  assert_equal "$(mock_get_call_num ${rm_bin})" 1
  assert_equal "$(mock_get_call_user ${rm_bin} 1)" "$(whoami)"
  assert_equal "$(mock_get_call_num ${sudo_bin})" 1
  assert_equal "$(mock_get_call_args "${sudo_bin}" 1)" "rm -rf $DATA_DIR"
  assert_file_not_exist "$DATA_DIR/testfile"
}
