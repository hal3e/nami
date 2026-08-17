set --global _nami_jj normal x
set --global CMD_DURATION 1000
set --global nami_cmd_duration_threshold 1000

function _nami_test_failed_prompt
    true | false
    fish_prompt
end

set rendered_prompt (_nami_test_failed_prompt | string collect)
set segment_state missing
string match --quiet -- '*x*1s*| 0 1*' "$rendered_prompt"; and set segment_state ready
set escape_state absent
string match --quiet -- "*\e*" "$rendered_prompt"; and set escape_state present
printf 'UNCOLORED:segments=%s,escapes=%s\n' "$segment_state" "$escape_state"
