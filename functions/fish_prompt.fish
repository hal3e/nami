function fish_prompt --description Nami
    set --local last_pipestatus $pipestatus
    set --local cmd_duration (_nami_format_duration "$CMD_DURATION" "$nami_cmd_duration_threshold")
    set --local failed_status
    string match --quiet --invert 0 -- $last_pipestatus; and set failed_status (string join ' ' -- $last_pipestatus)
    set --local pwd (_nami_format_pwd "$PWD" "$_nami_jj_workspace_root" "$fish_prompt_pwd_dir_length")

    set --local reset (set_color normal)
    set --local parts

    set --append parts (string join '' -- \
        (set_color $nami_color_start) "$nami_symbol_start" "$reset" \
        (set_color $nami_color_pwd) "$pwd" "$reset")

    set --local jj_color jj_suffix
    switch "$_nami_jj[1]"
        case querying
            set --append parts ' '
        case normal
            set jj_color $nami_color_jj
        case no_description
            set jj_color $nami_color_jj_no_description
        case empty
            set jj_color $nami_color_jj_empty
        case divergent
            set jj_color $nami_color_jj_divergent
        case conflict conflict_divergent
            set jj_color $nami_color_jj_conflict
    end

    contains -- "$_nami_jj[1]" divergent conflict_divergent; and set jj_suffix $nami_symbol_jj_divergent
    set --query _nami_jj[2]; and set --append parts (string join '' -- \
        (set_color $jj_color) "$_nami_jj[2]$jj_suffix" "$reset")

    test -z "$cmd_duration"; or set --append parts (string join '' -- \
        (set_color $nami_color_duration) "$cmd_duration" "$reset")
    test -z "$failed_status"; or set --append parts (string join '' -- \
        (set_color $nami_color_error) "| $failed_status" "$reset")

    set --local prompt_color $nami_color_prompt
    test -z "$failed_status"; or set prompt_color $nami_color_error

    printf '%s %s%s%s ' \
        (string join ' ' -- $parts) \
        (set_color $prompt_color) \
        "$nami_symbol_prompt" \
        "$reset"
end
