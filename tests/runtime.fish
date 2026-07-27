set project_root (path resolve (path dirname (status filename))/..)
source "$project_root/tests/helpers/runtime.fish"
set temp_root (mktemp -d)
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
mkdir -p "$config_root"
printf '%s\n' 'set --global fish_greeting' >"$config_root/config.fish"

set runtime_script '
source "$NAMI_TEST_HELPERS"
emit fish_prompt
nami_test_wait_for_jj no_description; or exit 1

printf "DEFAULT:jj-color=%s,prompt=%s\n" "$nami_color_jj" "$nami_symbol_prompt"
set path_state missing
string match --quiet --regex "nami" -- (fish_prompt | string collect); and set path_state ready
printf "ROOT:root=%s,path=%s\n" "$_nami_jj_workspace_root" "$path_state"
printf "RESULT:condition=%s,id=%s\n" "$_nami_jj[1]" "$_nami_jj[2]"

cd "$PWD/nested"
nami_test_wait_for_jj no_description; or exit 1
set path_state missing
string match --quiet --regex "nested" -- (fish_prompt | string collect); and set path_state ready
printf "NESTED:path=%s,worker=%s,id=%s\n" \
    "$path_state" (nami_test_worker_state) "$_nami_jj[2]"

cd "$NAMI_TEST_OUTSIDE"
set jj_state hidden
set --query _nami_jj; and set jj_state visible
printf "OUTSIDE:jj=%s,worker=%s\n" "$jj_state" (nami_test_worker_state)

set --global nami_ignored_jj_paths "$NAMI_TEST_REPO"
cd "$NAMI_TEST_REPO"
set jj_state hidden
set --query _nami_jj; and set jj_state visible
printf "IGNORED:jj=%s,worker=%s\n" "$jj_state" (nami_test_worker_state)

set --universal nami_symbol_prompt X
function fish_prompt
    echo user
end
emit nami_uninstall
set public_state removed
set --query nami_symbol_prompt; and set public_state present
set internal_count (count (set --names | string match "_nami_*"))
set prompt_state removed
functions --query fish_prompt; and set prompt_state present
printf "UNINSTALL:public=%s,internal=%s,prompt=%s\n" \
    "$public_state" "$internal_count" "$prompt_state"
'

nami_test_run_runtime "$project_root" "$temp_root" "$repo" "$runtime_script" \
    "NAMI_TEST_HELPERS=$project_root/tests/helpers/runtime.fish" \
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
    (contains -- "ROOT:root=$repo,path=ready" $output; echo $status) -eq 0
@test 'given initial query, when worker completes, then change ID and condition render' \
    (contains -- "RESULT:condition=no_description,id="(command jj --repository "$repo" --ignore-working-copy log --no-graph --revisions @ --template 'change_id.shortest().prefix()') $output; echo $status) -eq 0
@test 'given filesystem change, when JJ query completes, then operation head is unchanged' \
    "$operation_after" = "$operation_before"
@test 'given idle directory change, when PWD changes, then path and JJ refresh finish' \
    (contains -- "NESTED:path=ready,worker=idle,id="(command jj --repository "$repo" --ignore-working-copy log --no-graph --revisions @ --template 'change_id.shortest().prefix()') $output; echo $status) -eq 0
@test 'given directory outside JJ, when context refreshes, then segment and worker hide' \
    (contains -- 'OUTSIDE:jj=hidden,worker=idle' $output; echo $status) -eq 0
@test 'given ignored workspace, when context refreshes, then segment and worker hide' \
    (contains -- 'IGNORED:jj=hidden,worker=idle' $output; echo $status) -eq 0
@test 'given public setting and user prompt, when Nami uninstalls, then only internals clear' \
    (contains -- 'UNINSTALL:public=present,internal=0,prompt=present' $output; echo $status) -eq 0

nami_test_run_runtime "$project_root" "$temp_root" "$repo" \
    'emit fish_prompt; set segment hidden; set --query _nami_jj; and set segment visible; printf "MISSING:segment=%s\n" "$segment"' \
    "PATH=$temp_root/no-jj"
set missing_output $nami_test_runtime_output
set missing_warnings (
    string match --regex --all 'nami: jj query failed; will retry' -- $nami_test_runtime_stderr
)
@test 'given missing JJ, when prompt renders, then segment hides with one warning' \
    "$missing_output,"(count $missing_warnings) = 'MISSING:segment=hidden,1'

set failure_script '
source "$NAMI_TEST_HELPERS"
emit fish_prompt
nami_test_wait_for_jj_failure; or exit 1
emit fish_preexec true
set --erase PATH[1]
emit fish_prompt
nami_test_wait_for_jj no_description; or exit 1
printf "RECOVERY:condition=%s,id=%s\n" "$_nami_jj[1]" "$_nami_jj[2]"
'
nami_test_run_runtime "$project_root" "$temp_root" "$repo" "$failure_script" \
    "PATH=$project_root/tests/fixtures/failing-jj:$PATH" \
    "NAMI_TEST_HELPERS=$project_root/tests/helpers/runtime.fish"
set failure_output $nami_test_runtime_output
set failure_warnings (
    string match --regex --all 'nami: jj query failed; will retry' -- $nami_test_runtime_stderr
)
@test 'given failed query, when JJ becomes available, then next refresh recovers after one warning' \
    (contains -- "RECOVERY:condition=no_description,id="(
        command jj --repository "$repo" --ignore-working-copy log \
            --no-graph --revisions @ --template 'change_id.shortest().prefix()'
    ) $failure_output; and test (count $failure_warnings) -eq 1; echo $status) -eq 0

rm -rf "$temp_root"
