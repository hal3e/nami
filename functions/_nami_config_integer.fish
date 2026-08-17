function _nami_config_integer --argument-names variable_name fallback
    set --local value $$variable_name

    if test (count $value) = 1
        and string match --quiet --regex '^[0-9]+$' -- "$value"
        and test "$value" -ge 0 2>/dev/null
        printf '%s\n' "$value"
        return
    end

    if not contains -- "$variable_name" $_nami_warned_config
        set --global --append _nami_warned_config "$variable_name"
        printf 'nami: %s must be a non-negative integer; using %s\n' \
            "$variable_name" "$fallback" >&2
    end

    printf '%s\n' "$fallback"
end
