function _nami_format_pwd --argument-names current_pwd workspace_root segment_length
    set --local display_path

    if test "$segment_length" = 0
        set display_path (path basename "$current_pwd")
        test "$current_pwd" = /; and set display_path /
    else if test -n "$workspace_root"; and test "$workspace_root" != /
        set display_path (prompt_pwd --dir-length "$segment_length" --full-length-dirs 1 "$workspace_root")
        if test "$current_pwd" != "$workspace_root"
            set --local relative_path (string replace -- "$workspace_root/" '' "$current_pwd")
            set display_path "$display_path/"(prompt_pwd --dir-length "$segment_length" --full-length-dirs 1 "$relative_path")
        end
    else
        set display_path (prompt_pwd --dir-length "$segment_length" --full-length-dirs 1 "$current_pwd")
    end

    set --local bold_on \x1b'[1m'
    set --local dim_on \x1b'[2m'
    set --local attributes_off \x1b'[22m'

    if test "$display_path" = /
        printf '%s/%s' "$bold_on" "$attributes_off"
        return
    end

    set --local separator "$dim_on/$attributes_off"
    set --local formatted (string replace --regex '([^/]+)$' "$bold_on\$1$attributes_off" -- "$display_path")
    set formatted (string replace --all / "$separator" -- "$formatted")
    printf '%s' "$formatted"
end
