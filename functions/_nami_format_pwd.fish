function _nami_format_pwd --argument-names current_pwd workspace_root segment_length
    set --local color_arguments $argv[4..-1]
    set --query color_arguments[1]; or set color_arguments normal
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

    set --local plain (string join '' -- \
        (set_color normal) (set_color $color_arguments))
    set --local bold (string join '' -- \
        (set_color normal) (set_color --bold $color_arguments))
    set --local dim (string join '' -- \
        (set_color normal) (set_color --dim $color_arguments))

    if test "$display_path" = /
        printf '%s/%s' "$bold" "$plain"
        return
    end

    set --local separator "$dim/$plain"
    set --local formatted (string replace --regex '([^/]+)$' "$bold\$1$plain" -- "$display_path")
    set formatted (string replace --all / "$separator" -- "$formatted")
    printf '%s%s' "$plain" "$formatted"
end
