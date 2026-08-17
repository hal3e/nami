set project_root (path resolve (path dirname (status filename))/..)
source "$project_root/tests/helpers/runtime.fish"
set temp_root (command mktemp -d)
set workspace "$temp_root/first"
set second_workspace "$workspace/second"
set outside "$temp_root/outside"
set started_file "$temp_root/jj-started"
set gate_file "$temp_root/jj-gate"
set fixture_path "$project_root/tests/fixtures/slow-jj"

mkdir -p "$workspace/.jj" "$second_workspace/.jj" "$outside"
touch "$gate_file"

nami_test_run_runtime "$project_root" "$temp_root" "$workspace" \
    "$project_root/tests/scenarios/runtime_worker_lifecycle.fish" \
    "PATH=$fixture_path:$PATH" \
    "NAMI_TEST_HELPERS=$project_root/tests/helpers/runtime.fish" \
    "NAMI_TEST_JJ_STARTED=$started_file" \
    "NAMI_TEST_JJ_GATE=$gate_file" \
    "NAMI_TEST_WORKSPACE=$workspace" \
    "NAMI_TEST_SECOND_WORKSPACE=$second_workspace" \
    "NAMI_TEST_OUTSIDE=$outside"
set output $nami_test_runtime_output

@echo '=== worker lifecycle ==='

@test 'given foreground PWD change, when prompt is pending, then refresh stays deferred' \
    (contains -- 'DEFERRED:first=alive,starts=1' $output; echo $status) -eq 0
@test 'given blocked query, when next prompt renders elsewhere, then exactly one replacement starts' \
    (contains -- 'REPLACED:first=dead,second=alive,starts=2' $output; echo $status) -eq 0
@test 'given replacement query, when it completes, then latest workspace result wins' \
    (contains -- 'FINAL:rendered=ready,second=dead' $output; echo $status) -eq 0
@test 'given idle PWD change, when directory changes, then fresh query starts immediately' \
    (contains -- 'IDLE:rendered=ready,worker=dead,starts=3' $output; echo $status) -eq 0
@test 'given pending query, when directory leaves JJ, then worker stops without replacement' \
    (contains -- 'OUTSIDE:worker=dead,jobs=idle,starts=4,segment=hidden' $output; echo $status) -eq 0
@test 'given pending query, when workspace becomes ignored, then worker stops without replacement' \
    (contains -- 'IGNORED:worker=dead,jobs=idle,starts=5,segment=hidden' $output; echo $status) -eq 0
@test 'given pending query, when Nami uninstalls, then process and result file are removed' \
    (contains -- 'UNINSTALL:worker=dead,jobs=idle,result=removed' $output; echo $status) -eq 0

command rm -f -- "$started_file"
touch "$gate_file"
nami_test_run_runtime "$project_root" "$temp_root" "$workspace" \
    "$project_root/tests/scenarios/runtime_worker_exit.fish" \
    "PATH=$fixture_path:$PATH" \
    "NAMI_TEST_HELPERS=$project_root/tests/helpers/runtime.fish" \
    "NAMI_TEST_JJ_STARTED=$started_file" \
    "NAMI_TEST_JJ_GATE=$gate_file"
set exit_output $nami_test_runtime_output
set exit_record (string match -- 'EXIT:*' $exit_output)
set exit_pid (string replace --regex '^EXIT:pid=([^,]+),result=.*$' '$1' -- "$exit_record")
set exit_result (string replace --regex '^EXIT:pid=[^,]+,result=(.*)$' '$1' -- "$exit_record")

@test 'given pending query, when Fish exits, then worker process is stopped' \
    (nami_test_process_state "$exit_pid") = dead
@test 'given pending query, when Fish exits, then result file is removed' \
    (nami_test_file_state "$exit_result") = removed

rm -rf "$temp_root"
