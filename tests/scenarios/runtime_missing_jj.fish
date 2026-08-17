emit fish_prompt
set jj_needle (string join '' -- \
    (set_color $nami_color_jj_no_description) "$NAMI_TEST_CHANGE_ID")
set segment hidden
string match --quiet -- "*$jj_needle*" (fish_prompt | string collect); and set segment visible
printf 'MISSING:segment=%s\n' "$segment"
