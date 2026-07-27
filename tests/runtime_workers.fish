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
read first_pid <"$NAMI_TEST_JJ_STARTED"

emit fish_preexec "cd second"
cd "$PWD/second"
printf "DEFERRED:first=%s,starts=%s\n" \
    (nami_test_process_state "$first_pid") \
    (count (string split "\n" <"$NAMI_TEST_JJ_STARTED"))

emit fish_prompt
nami_test_wait_for_file_lines "$NAMI_TEST_JJ_STARTED" 2; or exit 1
set worker_pids (string match --regex "^[0-9]+\$" <"$NAMI_TEST_JJ_STARTED")
set second_pid "$worker_pids[2]"
printf "REPLACED:first=%s,second=%s,starts=%s\n" \
    (nami_test_process_state "$first_pid") \
    (nami_test_process_state "$second_pid") \
    (count (string split "\n" <"$NAMI_TEST_JJ_STARTED"))

command rm "$NAMI_TEST_JJ_GATE"
set jj_needle (string join "" -- (set_color $nami_color_jj) second)
nami_test_wait_for_prompt "$jj_needle"; or exit 1
printf "FINAL:rendered=ready,second=%s\n" (nami_test_process_state "$second_pid")
'

nami_test_run_runtime "$project_root" "$temp_root" "$workspace" "$runtime_script" \
    "PATH=$fixture_path:$PATH" \
    "NAMI_TEST_HELPERS=$project_root/tests/helpers/runtime.fish" \
    "NAMI_TEST_JJ_STARTED=$started_file" \
    "NAMI_TEST_JJ_GATE=$gate_file"
set output $nami_test_runtime_output

@echo '=== worker lifecycle ==='

@test 'given foreground PWD change, when prompt is pending, then refresh stays deferred' \
    (contains -- 'DEFERRED:first=alive,starts=1' $output; echo $status) -eq 0
@test 'given blocked query, when next prompt renders elsewhere, then exactly one replacement starts' \
    (contains -- 'REPLACED:first=dead,second=alive,starts=2' $output; echo $status) -eq 0
@test 'given replacement query, when it completes, then latest workspace result wins' \
    (contains -- 'FINAL:rendered=ready,second=dead' $output; echo $status) -eq 0

rm -rf "$temp_root"
