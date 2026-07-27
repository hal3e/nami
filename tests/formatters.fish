set project_root (path resolve (path dirname (status filename))/..)
set --prepend fish_function_path "$project_root/functions"

function _strip_ansi --argument-names input
    string replace --all --regex '\x1b(?:\[[0-9;]*m|\(B)' '' -- "$input"
end

function _prompt_contains --argument-names color text
    set --local needle (set_color "$color")"$text"
    string match --quiet -- "*$needle*" (fish_prompt | string collect)
end

@echo '=== duration ==='

@test 'given duration below threshold, when formatted, then it is hidden' \
    (_nami_format_duration 999 1000 | string collect --allow-empty) = ''
@test 'given duration at threshold, when formatted, then it is shown' \
    (_nami_format_duration 1000 1000) = 1s
@test 'given duration below one minute, when formatted, then it is truncated to tenths' \
    (_nami_format_duration 59999 1000) = 59.9s
@test 'given exact minute, when formatted, then zero seconds are omitted' \
    (_nami_format_duration 60000 1000) = 1m
@test 'given hour minute and seconds, when formatted, then units are joined' \
    (_nami_format_duration 3661100 1000) = 1h1m1.1s

@echo '=== pwd ==='

@test 'given nested JJ path, when shortened, then workspace root remains readable' \
    (_strip_ansi (_nami_format_pwd /opt/acme/nami/src/lib /opt/acme/nami 1 | string collect)) = /o/a/nami/s/lib
@test 'given zero segment length, when shortened, then only current directory remains' \
    (_strip_ansi (_nami_format_pwd /opt/acme/nami/src/lib /opt/acme/nami 0 | string collect)) = lib
@test 'given filesystem root, when formatted, then root remains visible' \
    (_strip_ansi (_nami_format_pwd / '' 1 | string collect)) = /
@test 'given current directory, when formatted, then basename is bold' (
    set styled (_nami_format_pwd /opt/acme/nami/src/lib /opt/acme/nami 1 | string collect)
    string match --quiet --regex '\x1b\[1mlib\x1b\[22m$' -- "$styled"
    echo $status
) -eq 0
@test 'given hidden parent directory, when shortened, then leading dot remains meaningful' \
    (_strip_ansi (_nami_format_pwd /tmp/.config/project '' 1 | string collect)) = /t/.c/project

@echo '=== jj rendering ==='

set nami_color_jj blue
set nami_color_jj_empty green
set nami_color_jj_no_description yellow
set nami_color_jj_conflict red
set nami_color_jj_divergent magenta
set nami_symbol_jj_divergent ≠

set _nami_jj normal x
@test 'given described change, when prompt renders, then normal JJ color is used' \
    (_prompt_contains blue x; echo $status) -eq 0

set _nami_jj empty x
@test 'given empty change, when prompt renders, then empty color is used' \
    (_prompt_contains green x; echo $status) -eq 0

set _nami_jj no_description x
@test 'given undescribed change, when prompt renders, then missing-description color is used' \
    (_prompt_contains yellow x; echo $status) -eq 0

set _nami_jj divergent x
@test 'given divergent change, when prompt renders, then divergent color and symbol render' (
    _prompt_contains magenta x; and string match --quiet -- '*x≠*' (_strip_ansi (fish_prompt | string collect))
    echo $status
) -eq 0

set _nami_jj conflict x
@test 'given conflicted change, when prompt renders, then conflict color is used' \
    (_prompt_contains red x; echo $status) -eq 0

set _nami_jj conflict_divergent x
@test 'given conflicted divergent change, when prompt renders, then conflict wins and symbol remains' (
    _prompt_contains red x; and string match --quiet -- '*x≠*' (_strip_ansi (fish_prompt | string collect))
    echo $status
) -eq 0

@echo '=== mode and prompt ==='

set fish_key_bindings fish_default_key_bindings
@test 'given default key bindings, when mode renders, then it is hidden' \
    (fish_mode_prompt | string collect --allow-empty | string length) -eq 0

set fish_key_bindings fish_vi_key_bindings
set fish_bind_mode insert
@test 'given vi insert mode, when mode renders, then lowercase i is shown' \
    (_strip_ansi (fish_mode_prompt | string collect)) = 'i '
set fish_bind_mode default
@test 'given vi normal mode, when mode renders, then lowercase n is shown' \
    (_strip_ansi (fish_mode_prompt | string collect)) = 'n '
set fish_bind_mode replace
@test 'given vi replace mode, when mode renders, then lowercase r is shown' \
    (_strip_ansi (fish_mode_prompt | string collect)) = 'r '
set fish_bind_mode visual
@test 'given vi visual mode, when mode renders, then lowercase v is shown' \
    (_strip_ansi (fish_mode_prompt | string collect)) = 'v '

set nami_color_start normal
set nami_color_pwd normal
set nami_color_duration normal
set nami_color_error red
set nami_color_prompt normal
set nami_symbol_start ''
set nami_symbol_prompt '>'
set fish_prompt_pwd_dir_length 0
set nami_cmd_duration_threshold 999999999
set --erase _nami_jj_workspace_root

set _nami_jj querying
true
set querying_prompt (_strip_ansi (fish_prompt | string collect))
set _nami_jj normal x
true
set ready_prompt (_strip_ansi (fish_prompt | string collect))
@test 'given one-character JJ result, when query completes, then prompt symbol remains stable' \
    (string length -- "$querying_prompt") -eq (string length -- "$ready_prompt")

set --erase _nami_jj
set --global CMD_DURATION 1000
set nami_cmd_duration_threshold 1000
function _prompt_after_failed_pipeline
    true | false
    fish_prompt
end
@test 'given duration and failed pipeline, when prompt renders, then segments keep stable order' \
    (_strip_ansi (_prompt_after_failed_pipeline | string collect)) = (path basename "$PWD")' 1s | 0 1 > '
set --erase CMD_DURATION
