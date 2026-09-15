functions --erase _nami_find_jj_root _nami_start_jj_worker _nami_stop_jj_worker

function _nami_find_jj_root --argument-names directory
    echo "$directory"
end

function _nami_start_jj_worker --argument-names workspace_root
    printf 'REFRESH:%s\n' (path basename "$workspace_root") >>"$NAMI_TEST_PHASE_RESULT"
end

function _nami_stop_jj_worker
end

function _nami_test_idle_change
    cd "$NAMI_TEST_PHASE_FIRST"
    printf 'IDLE\n' >>"$NAMI_TEST_PHASE_RESULT"
end

bind \cx _nami_test_idle_change
