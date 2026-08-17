set project_root (path resolve (path dirname (status filename))/..)
source "$project_root/tests/helpers/runtime.fish"
set temp_root (command mktemp -d)
set config_root "$temp_root/fish"
set repo "$temp_root/nami"
set outside "$temp_root/outside"

command jj git init "$repo" >/dev/null 2>/dev/null
mkdir -p "$repo/nested" "$outside"
printf 'change\n' >"$repo/file"
set operation_before (
    command jj --ignore-working-copy --repository "$repo" \
        op log --limit 1 --no-graph --template 'id.short()'
)
set change_id (
    command jj --repository "$repo" --ignore-working-copy log \
        --no-graph --revisions @ --template 'change_id.shortest().prefix()'
)
mkdir -p "$config_root"
printf '%s\n' 'set --global fish_greeting' >"$config_root/config.fish"

nami_test_run_runtime "$project_root" "$temp_root" "$repo" \
    "$project_root/tests/scenarios/runtime_core.fish" \
    "NAMI_TEST_HELPERS=$project_root/tests/helpers/runtime.fish" \
    "NAMI_TEST_CHANGE_ID=$change_id" \
    "NAMI_TEST_OUTSIDE=$outside" \
    "NAMI_TEST_REPO=$repo"
set runtime_status "$nami_test_runtime_status"
set output $nami_test_runtime_output
set runtime_errors "$nami_test_runtime_stderr"
set operation_after (
    command jj --ignore-working-copy --repository "$repo" \
        op log --limit 1 --no-graph --template 'id.short()'
)

@echo '=== async runtime ==='

@test 'given hermetic runtime, when prompt exits, then Fish reports success' "$runtime_status" = 0
@test 'given hermetic runtime, when prompt exits, then stderr remains empty' "$runtime_errors" = ''
@test 'given fresh configuration, when Nami loads, then documented defaults apply' \
    (contains -- 'DEFAULT:jj-color=blue,prompt=>' $output; echo $status) -eq 0
@test 'given JJ workspace, when Nami loads, then root-aware path is ready' \
    (contains -- 'ROOT:path=ready' $output; echo $status) -eq 0
@test 'given initial query, when worker completes, then change ID and condition render' \
    (contains -- 'RESULT:rendered=ready' $output; echo $status) -eq 0
@test 'given filesystem change, when JJ query completes, then operation head is unchanged' \
    "$operation_after" = "$operation_before"
@test 'given idle directory change, when PWD changes, then path and JJ refresh finish' \
    (contains -- 'NESTED:path=ready,jj=ready' $output; echo $status) -eq 0
@test 'given directory outside JJ, when context refreshes, then segment hides' \
    (contains -- 'OUTSIDE:jj=hidden' $output; echo $status) -eq 0
@test 'given ignored workspace, when context refreshes, then segment hides' \
    (contains -- 'IGNORED:jj=hidden' $output; echo $status) -eq 0
@test 'given public setting and user prompt, when Nami uninstalls, then only internals clear' \
    (contains -- 'UNINSTALL:public=present,internal=0,prompt=present' $output; echo $status) -eq 0

nami_test_run_runtime "$project_root" "$temp_root" "$outside" \
    "$project_root/tests/scenarios/runtime_uncolored.fish" \
    "TERM=dumb"
set uncolored_output $nami_test_runtime_output
@test 'given terminal without color output, when prompt renders, then text remains and escapes are absent' \
    (contains -- 'UNCOLORED:segments=ready,escapes=absent' $uncolored_output; echo $status) -eq 0

nami_test_run_runtime "$project_root" "$temp_root" "$repo" \
    "$project_root/tests/scenarios/runtime_missing_jj.fish" \
    "PATH=$temp_root/no-jj" \
    "NAMI_TEST_CHANGE_ID=$change_id"
set missing_output $nami_test_runtime_output
set missing_warnings (
    string match --regex --all 'nami: jj query failed; will retry' -- $nami_test_runtime_stderr
)
@test 'given missing JJ, when prompt renders, then segment hides with one warning' \
    "$missing_output,"(count $missing_warnings) = 'MISSING:segment=hidden,1'

nami_test_run_runtime "$project_root" "$temp_root" "$repo" \
    "$project_root/tests/scenarios/runtime_failure_recovery.fish" \
    "PATH=$project_root/tests/fixtures/failing-jj:$PATH" \
    "NAMI_TEST_HELPERS=$project_root/tests/helpers/runtime.fish" \
    "NAMI_TEST_CHANGE_ID=$change_id"
set failure_output $nami_test_runtime_output
set failure_warnings (
    string match --regex --all 'nami: jj query failed; will retry' -- $nami_test_runtime_stderr
)
@test 'given failed query, when JJ becomes available, then next refresh recovers after one warning' \
    (contains -- 'RECOVERY:rendered=ready' $failure_output; and test (count $failure_warnings) -eq 1; echo $status) -eq 0

nami_test_run_runtime "$project_root" "$temp_root" "$outside" \
    "$project_root/tests/scenarios/runtime_invalid_config.fish"
set invalid_output $nami_test_runtime_output
set invalid_stderr $nami_test_runtime_stderr
set threshold_warnings (
    string match --regex --all \
        'nami: nami_cmd_duration_threshold must be a non-negative integer; using 1000' \
        -- "$invalid_stderr"
)
set pwd_warnings (
    string match --regex --all \
        'nami: fish_prompt_pwd_dir_length must be a non-negative integer; using 1' \
        -- "$invalid_stderr"
)
set unexpected_config_errors (
    string split '\n' -- (string trim -- "$invalid_stderr") |
        string match --invert --regex '^nami: '
)
@test 'given invalid numeric settings, when prompt renders twice, then defaults apply with one warning each' \
    (contains -- 'INVALID:segments=ready' $invalid_output; and test (count $threshold_warnings) -eq 1; and test (count $pwd_warnings) -eq 1; echo $status) -eq 0
@test 'given invalid numeric settings, when prompt renders, then stderr has no builtin diagnostics' \
    (count $unexpected_config_errors) -eq 0

rm -rf "$temp_root"
