source "$NAMI_TEST_HELPERS"
emit fish_prompt
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 1; or exit 1
set worker_pids (nami_test_worker_pids "$NAMI_TEST_JJ_STARTED")
printf 'EXIT:pid=%s,result=%s\n' "$worker_pids[1]" "$_nami_jj_worker_result_file"
