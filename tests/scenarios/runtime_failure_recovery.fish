source "$NAMI_TEST_HELPERS"
set jj_needle (string join '' -- \
    (set_color $nami_color_jj_no_description) "$NAMI_TEST_CHANGE_ID")
emit fish_prompt
nami_test_wait_for_no_jobs; or exit 1
emit fish_preexec true
set --erase PATH[1]
emit fish_prompt
nami_test_wait_for_prompt "$jj_needle"; or exit 1
printf 'RECOVERY:rendered=ready\n'
