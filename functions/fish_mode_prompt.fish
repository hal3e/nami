function fish_mode_prompt
    test "$fish_key_bindings" = fish_default_key_bindings; and return

    set --local mode_color
    set --local mode_symbol

    switch "$fish_bind_mode"
        case default
            set mode_color (set_color $fish_color_selection)
            set mode_symbol n
        case insert
            set mode_color (set_color $fish_color_selection)
            set mode_symbol i
        case replace replace_one
            set mode_color (set_color $fish_color_match)
            set mode_symbol r
        case visual
            set mode_color (set_color $fish_color_match)
            set mode_symbol v
        case '*'
            return
    end

    printf '%s%s%s ' "$mode_color" "$mode_symbol" (set_color normal)
end
