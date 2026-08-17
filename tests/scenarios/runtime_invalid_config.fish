set --global CMD_DURATION 1000
set --global nami_cmd_duration_threshold 999999999999999999999999999999
set --global fish_prompt_pwd_dir_length -1

set rendered_prompt (fish_prompt | string collect)
fish_prompt >/dev/null

set segment_state missing
string match --quiet -- '*1s*' "$rendered_prompt"; and string match --quiet -- "*"(path basename "$PWD")"*" "$rendered_prompt"; and set segment_state ready
printf 'INVALID:segments=%s\n' "$segment_state"
