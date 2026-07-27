function _nami_format_duration --argument-names duration_ms threshold_ms
    test -n "$duration_ms"; or return
    test "$duration_ms" -ge "$threshold_ms"; or return

    set --local hours (math --scale=0 "floor($duration_ms / 3600000)")
    set --local minutes (math --scale=0 "floor($duration_ms / 60000) % 60")
    set --local seconds (math --scale=1 "floor($duration_ms / 100) / 10 % 60")
    set --local parts

    test "$hours" -gt 0; and set --append parts "$hours"h
    test "$minutes" -gt 0; and set --append parts "$minutes"m
    test "$seconds" -gt 0; and set --append parts "$seconds"s

    string join '' -- $parts
end
