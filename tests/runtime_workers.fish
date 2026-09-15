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

@test 'given blocked query, when idle PWD changes, then exactly one replacement starts' \
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

set phase_first "$temp_root/phase-first"
set phase_second "$temp_root/phase-second"
set phase_result "$temp_root/phase-result"
set phase_scenario "$project_root/tests/scenarios/runtime_refresh_phase.fish"
mkdir -p "$phase_first" "$phase_second"

set init_command "source "(string escape -- "$phase_scenario")
set fish_command (string join ' ' -- \
    (string escape -- (status fish-path)) \
    --interactive \
    --init-command \
    (string escape -- "$init_command"))

pushd "$phase_first" >/dev/null; or exit 1
begin
    printf '%s\n' \
        'cd "$NAMI_TEST_PHASE_SECOND"; printf "FOREGROUND\n" >>"$NAMI_TEST_PHASE_RESULT"'
    printf '\x18'
    printf '%s\n' exit
end | env \
    XDG_CONFIG_HOME="$temp_root" \
    NAMI_TEST_PHASE_FIRST="$phase_first" \
    NAMI_TEST_PHASE_SECOND="$phase_second" \
    NAMI_TEST_PHASE_RESULT="$phase_result" \
    TERM=dumb \
    script --quiet --return --flush --command "$fish_command" /dev/null >/dev/null
set phase_status $pipestatus[2]
popd >/dev/null

set phase_output (string split '\n' <"$phase_result")

@test 'given foreground PWD change, when command still runs, then refresh stays deferred' \
    (string join ',' -- $phase_output[1..2]) = 'REFRESH:phase-first,FOREGROUND'
@test 'given deferred PWD change, when next prompt renders, then context refreshes' \
    "$phase_output[3]" = 'REFRESH:phase-second'
@test 'given key-binding PWD change, when binding still runs, then context refreshes immediately' \
    (string join ',' -- $phase_output[4..5]) = 'REFRESH:phase-first,IDLE'
@test 'given reader-phase scenario, when Fish exits, then harness succeeds' "$phase_status" -eq 0

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
