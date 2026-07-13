function _nami_find_jj_root --argument-names directory
    while true
        if test -d "$directory/.jj"
            printf '%s\n' "$directory"
            return 0
        end

        set --local parent (path dirname "$directory")
        test "$parent" = "$directory"; and return 1
        set directory "$parent"
    end
end
