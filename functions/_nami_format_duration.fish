function _nami_format_duration --argument-names duration_ms threshold_ms
    string match --quiet --regex '^[0-9]+$' -- "$duration_ms"; or return
    string match --quiet --regex '^[0-9]+$' -- "$threshold_ms"; or return
    test "$duration_ms" -ge 0 2>/dev/null; or return
    test "$threshold_ms" -ge 0 2>/dev/null; or return
    test "$duration_ms" -ge "$threshold_ms"; or return

    if test "$duration_ms" -lt 100
        printf '<0.1s\n'
        return
    end

    set --local hours (math --scale=0 "floor($duration_ms / 3600000)")
    set --local minutes (math --scale=0 "floor($duration_ms / 60000) % 60")
    set --local seconds (math --scale=1 "floor($duration_ms / 100) / 10 % 60")
    set --local parts

    test "$hours" -gt 0; and set --append parts "$hours"h
    test "$minutes" -gt 0; and set --append parts "$minutes"m
    test "$seconds" -gt 0; and set --append parts "$seconds"s

    string join '' -- $parts
end
