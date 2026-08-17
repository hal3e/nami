function nami_test_run_runtime --argument-names project_root temp_root working_directory scenario_file
    set --local environment $argv[5..-1]
    set --local config_root "$temp_root/fish"
    set --local stdout_file "$temp_root/runtime.stdout"
    set --local stderr_file "$temp_root/runtime.stderr"

    mkdir -p "$config_root/conf.d" "$config_root/functions"
    cp "$project_root/conf.d/nami.fish" "$config_root/conf.d/"
    cp "$project_root"/functions/*.fish "$config_root/functions/"
    pushd "$working_directory" >/dev/null; or return 1
    env $environment XDG_CONFIG_HOME="$temp_root" (status fish-path) \
        --interactive "$scenario_file" >"$stdout_file" 2>"$stderr_file"
    set --local runtime_status $status
    popd >/dev/null

    set --global nami_test_runtime_status "$runtime_status"
    set --global nami_test_runtime_output (nami_test_records "$stdout_file")
    set --global nami_test_runtime_stderr (string collect <"$stderr_file")
    command rm -f -- "$stdout_file" "$stderr_file"
end

function nami_test_wait_for_file_lines --argument-names file minimum
    for attempt in (seq 700)
        if test -s "$file"
            test (count (string split '\n' <"$file")) -ge "$minimum"; and return 0
        end
        sleep 0.01
    end
    return 1
end

function nami_test_wait_for_prompt --argument-names expected
    for attempt in (seq 700)
        string match --quiet -- "*$expected*" (fish_prompt | string collect); and return 0
        sleep 0.01
    end
    return 1
end

function nami_test_wait_for_no_jobs
    for attempt in (seq 700)
        jobs --query; or return 0
        sleep 0.01
    end
    return 1
end

function nami_test_process_alive --argument-names process_id
    string match --quiet --regex '^[0-9]+$' -- "$process_id"; or return 1
    /bin/sh -c 'kill -0 "$1" 2>/dev/null' sh "$process_id"
end

function nami_test_process_state --argument-names process_id
    nami_test_process_alive "$process_id"; and echo alive; or echo dead
end

function nami_test_worker_pids --argument-names file
    string match --regex '^[0-9]+$' <"$file"
end

function nami_test_worker_count --argument-names file
    count (nami_test_worker_pids "$file")
end

function nami_test_job_state
    jobs --query; and echo running; or echo idle
end

function nami_test_file_state --argument-names file
    test -e "$file"; and echo present; or echo removed
end

function nami_test_records --argument-names file
    string replace --filter --regex '^.*?([A-Z][A-Z-]*:.*)$' '$1' <"$file"
end
