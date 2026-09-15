source "$NAMI_TEST_HELPERS"
emit fish_prompt
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 1; or exit 1
set worker_pids (nami_test_worker_pids "$NAMI_TEST_JJ_STARTED")
set first_pid "$worker_pids[1]"

cd "$NAMI_TEST_SECOND_WORKSPACE"
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 2; or exit 1
set worker_pids (nami_test_worker_pids "$NAMI_TEST_JJ_STARTED")
set second_pid "$worker_pids[2]"
printf 'REPLACED:first=%s,second=%s,starts=%s\n' \
    (nami_test_process_state "$first_pid") \
    (nami_test_process_state "$second_pid") \
    (nami_test_worker_count "$NAMI_TEST_JJ_STARTED")

command rm "$NAMI_TEST_JJ_GATE"
set second_needle (string join '' -- (set_color $nami_color_jj) second)
nami_test_wait_for_prompt "$second_needle"; or exit 1
printf 'FINAL:rendered=ready,second=%s\n' (nami_test_process_state "$second_pid")

cd "$NAMI_TEST_WORKSPACE"
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 3; or exit 1
set worker_pids (nami_test_worker_pids "$NAMI_TEST_JJ_STARTED")
set idle_pid "$worker_pids[3]"
set first_needle (string join '' -- (set_color $nami_color_jj) first)
nami_test_wait_for_prompt "$first_needle"; or exit 1
printf 'IDLE:rendered=ready,worker=%s,starts=%s\n' \
    (nami_test_process_state "$idle_pid") \
    (nami_test_worker_count "$NAMI_TEST_JJ_STARTED")

command touch "$NAMI_TEST_JJ_GATE"
emit fish_prompt
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 4; or exit 1
set worker_pids (nami_test_worker_pids "$NAMI_TEST_JJ_STARTED")
set outside_pid "$worker_pids[4]"
cd "$NAMI_TEST_OUTSIDE"
nami_test_wait_for_no_jobs; or exit 1
set outside_segment hidden
string match --quiet -- "*$first_needle*" (fish_prompt | string collect); and set outside_segment visible
printf 'OUTSIDE:worker=%s,jobs=%s,starts=%s,segment=%s\n' \
    (nami_test_process_state "$outside_pid") \
    (nami_test_job_state) \
    (nami_test_worker_count "$NAMI_TEST_JJ_STARTED") \
    "$outside_segment"

cd "$NAMI_TEST_SECOND_WORKSPACE"
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 5; or exit 1
set worker_pids (nami_test_worker_pids "$NAMI_TEST_JJ_STARTED")
set ignored_pid "$worker_pids[5]"
set --global nami_ignored_jj_paths "$NAMI_TEST_SECOND_WORKSPACE"
emit fish_prompt
nami_test_wait_for_no_jobs; or exit 1
set ignored_segment hidden
string match --quiet -- "*$second_needle*" (fish_prompt | string collect); and set ignored_segment visible
printf 'IGNORED:worker=%s,jobs=%s,starts=%s,segment=%s\n' \
    (nami_test_process_state "$ignored_pid") \
    (nami_test_job_state) \
    (nami_test_worker_count "$NAMI_TEST_JJ_STARTED") \
    "$ignored_segment"

set --erase nami_ignored_jj_paths
cd "$NAMI_TEST_WORKSPACE"
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 6; or exit 1
set worker_pids (nami_test_worker_pids "$NAMI_TEST_JJ_STARTED")
set uninstall_pid "$worker_pids[6]"
set uninstall_result "$_nami_jj_worker_result_file"
emit nami_uninstall
nami_test_wait_for_no_jobs; or exit 1
printf 'UNINSTALL:worker=%s,jobs=%s,result=%s\n' \
    (nami_test_process_state "$uninstall_pid") \
    (nami_test_job_state) \
    (nami_test_file_state "$uninstall_result")
