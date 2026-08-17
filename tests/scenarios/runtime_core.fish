source "$NAMI_TEST_HELPERS"
emit fish_prompt
set jj_needle (string join '' -- \
    (set_color $nami_color_jj_no_description) "$NAMI_TEST_CHANGE_ID")
nami_test_wait_for_prompt "$jj_needle"; or exit 1

printf 'DEFAULT:jj-color=%s,prompt=%s\n' "$nami_color_jj" "$nami_symbol_prompt"
set rendered_prompt (fish_prompt | string collect)
set path_state missing
string match --quiet --regex nami -- "$rendered_prompt"; and set path_state ready
set result_state missing
string match --quiet -- "*$jj_needle*" "$rendered_prompt"; and set result_state ready
printf 'ROOT:path=%s\n' "$path_state"
printf 'RESULT:rendered=%s\n' "$result_state"

cd "$PWD/nested"
nami_test_wait_for_no_jobs; or exit 1
set rendered_prompt (fish_prompt | string collect)
set path_state missing
string match --quiet --regex nested -- "$rendered_prompt"; and set path_state ready
set result_state missing
string match --quiet -- "*$jj_needle*" "$rendered_prompt"; and set result_state ready
printf 'NESTED:path=%s,jj=%s\n' "$path_state" "$result_state"

cd "$NAMI_TEST_OUTSIDE"
set jj_state hidden
string match --quiet -- "*$jj_needle*" (fish_prompt | string collect); and set jj_state visible
printf 'OUTSIDE:jj=%s\n' "$jj_state"

set --global nami_ignored_jj_paths "$NAMI_TEST_REPO"
cd "$NAMI_TEST_REPO"
set jj_state hidden
string match --quiet -- "*$jj_needle*" (fish_prompt | string collect); and set jj_state visible
printf 'IGNORED:jj=%s\n' "$jj_state"

set --universal nami_symbol_prompt X
function fish_prompt
    echo user
end
emit nami_uninstall
set public_state removed
set --query nami_symbol_prompt; and set public_state present
set internal_count (count (set --names | string match '_nami_*'))
set prompt_state removed
functions --query fish_prompt; and set prompt_state present
printf 'UNINSTALL:public=%s,internal=%s,prompt=%s\n' \
    "$public_state" "$internal_count" "$prompt_state"
