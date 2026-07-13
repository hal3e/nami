set project_root (path resolve (path dirname (status filename))/..)
source "$project_root/tests/helpers/runtime.fish"
set temp_root (mktemp -d)
set workspace "$temp_root/first"
set second_workspace "$workspace/second"
set started_file "$temp_root/jj-started"
set gate_file "$temp_root/jj-gate"
set fixture_path "$project_root/tests/fixtures/slow-jj"

mkdir -p "$workspace/.jj" "$second_workspace/.jj"
touch "$gate_file"

set runtime_script '
source "$NAMI_TEST_HELPERS"
emit fish_prompt
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 1; or exit 1
set first_pid $_nami_jj_worker_pid

emit fish_preexec "cd second"
cd "$PWD/second"
printf "DEFERRED:first=%s,current=%s,starts=%s\n" \
    (nami_test_process_state "$first_pid") \
    (nami_test_worker_state) \
    (count (string split "\n" <"$NAMI_TEST_JJ_STARTED"))

emit fish_postexec "cd second"
emit fish_prompt
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 2; or exit 1
printf "REPLACED:first=%s,current=%s,starts=%s\n" \
    (nami_test_process_state "$first_pid") \
    (nami_test_worker_state) \
    (count (string split "\n" <"$NAMI_TEST_JJ_STARTED"))

command rm "$NAMI_TEST_JJ_GATE"
nami_test_wait_for_jj normal; or exit 1
printf "FINAL:condition=%s,id=%s,worker=%s\n" \
    "$_nami_jj[1]" "$_nami_jj[2]" (nami_test_worker_state)
'

nami_test_run_runtime "$project_root" "$temp_root" "$workspace" "$runtime_script" \
    "PATH=$fixture_path:$PATH" \
    "NAMI_TEST_HELPERS=$project_root/tests/helpers/runtime.fish" \
    "NAMI_TEST_JJ_STARTED=$started_file" \
    "NAMI_TEST_JJ_GATE=$gate_file"
set output $nami_test_runtime_output

@echo '=== worker lifecycle ==='

@test 'given foreground PWD change, when prompt is pending, then refresh stays deferred' \
    (contains -- 'DEFERRED:first=alive,current=running,starts=1' $output; echo $status) -eq 0
@test 'given blocked query, when next prompt renders elsewhere, then exactly one replacement starts' \
    (contains -- 'REPLACED:first=dead,current=running,starts=2' $output; echo $status) -eq 0
@test 'given replacement query, when it completes, then latest workspace result wins' \
    (contains -- 'FINAL:condition=normal,id=second,worker=idle' $output; echo $status) -eq 0

rm -rf "$temp_root"
