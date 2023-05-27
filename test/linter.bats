#!/usr/bin/env bats

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  load 'test_helper/bats-detik/lib/utils'
  load 'test_helper/bats-detik/lib/linter'
}

@test "lint assertions" {
  find_results=$(find test/ -path "*.bats" \
    -not -path "*/bats/*" \
    -not -path "*/test_helper/bats-file/*" \
    -not -path "*/test_helper/bats-support/*" \
    -not -path "*/test_helper/bats-detik/*" \
    -not -path "*/test_helper/bats-assert/*" \
    -not -path "*/.data/*"
  )

  while IFS= read -r file; do
      echo "Processing file: $file"
    	run lint $file
      assert_equal "$status" 0
  done <<< "$find_results"
}
