status is-interactive; or exit

set --query nami_symbol_start; or set --global nami_symbol_start ''
set --query nami_symbol_prompt; or set --global nami_symbol_prompt '>'
set --query nami_symbol_jj_divergent; or set --global nami_symbol_jj_divergent ≠

set --query nami_color_pwd; or set --global nami_color_pwd $fish_color_normal
set --query nami_color_jj; or set --global nami_color_jj blue
set --query nami_color_jj_empty; or set --global nami_color_jj_empty green
set --query nami_color_jj_no_description; or set --global nami_color_jj_no_description yellow
set --query nami_color_jj_conflict; or set --global nami_color_jj_conflict red
set --query nami_color_jj_divergent; or set --global nami_color_jj_divergent red
set --query nami_color_start; or set --global nami_color_start $fish_color_normal
set --query nami_color_prompt; or set --global nami_color_prompt $fish_color_normal
set --query nami_color_duration; or set --global nami_color_duration $fish_color_normal
set --query nami_color_error; or set --global nami_color_error $fish_color_error

set --query fish_prompt_pwd_dir_length; or set --global fish_prompt_pwd_dir_length 1
set --query nami_cmd_duration_threshold; or set --global nami_cmd_duration_threshold 1000
set --query nami_ignored_jj_paths; or set --global nami_ignored_jj_paths

function _nami_stop_jj_worker --on-event fish_exit
    functions --erase _nami_receive_jj 2>/dev/null

    if set --query _nami_jj_worker_pid
        /bin/sh -c 'kill -KILL "$1" 2>/dev/null' sh "$_nami_jj_worker_pid"
        wait "$_nami_jj_worker_pid" 2>/dev/null
    end

    set --query _nami_jj_worker_result_file; and command rm -f -- "$_nami_jj_worker_result_file"
    set --erase _nami_jj_worker_pid _nami_jj_worker_result_file
end

function _nami_fail_jj
    set --erase _nami_jj

    set --query _nami_warned_jj; and return
    set --global _nami_warned_jj 1
    printf 'nami: jj query failed; will retry\n' >&2
end

function _nami_start_jj_worker --argument-names workspace_root
    set --local jj_path (command --search jj); or begin
        _nami_fail_jj
        return 1
    end

    set --local result_file (command mktemp); or begin
        _nami_fail_jj
        return 1
    end
    set --local template '
        change_id.shortest().prefix()
        ++ "\t"
        ++ if(
            conflict,
            if(divergent, "conflict_divergent", "conflict"),
            if(
                divergent,
                "divergent",
                if(empty, "empty", if(description, "normal", "no_description"))
            )
        )
        ++ "\n"
    '

    # Delay fast process-exit delivery until the receiver is registered.
    block
    command "$jj_path" --no-integrate-operation --quiet --repository "$workspace_root" \
        log --no-pager --color=never --no-graph --revisions @ --template "$template" >"$result_file" 2>/dev/null &
    set --global _nami_jj_worker_pid $last_pid
    set --global _nami_jj_worker_result_file "$result_file"

    function _nami_receive_jj --on-process-exit "$_nami_jj_worker_pid" \
        --inherit-variable result_file \
        --argument-names event process_id exit_status
        set --local change_id condition
        test "$exit_status" = 0; and read --delimiter \t change_id condition <"$result_file"
        command rm -f -- "$result_file"
        set --erase _nami_jj_worker_pid _nami_jj_worker_result_file

        if test -n "$change_id"; and test -n "$condition"
            set --global _nami_jj "$condition" "$change_id"
        else
            _nami_fail_jj
        end

        commandline --function repaint 2>/dev/null
        functions --erase _nami_receive_jj
    end
end

function _nami_defer_refresh --on-event fish_preexec
    set --global _nami_refresh_deferred
end

function _nami_refresh --on-event fish_prompt
    set --erase _nami_refresh_deferred

    set --local previous_root "$_nami_jj_workspace_root"
    set --local workspace_root (_nami_find_jj_root "$PWD")

    _nami_stop_jj_worker
    set --global _nami_jj_workspace_root "$workspace_root"

    if test -z "$workspace_root"; or contains -- "$workspace_root" $nami_ignored_jj_paths
        set --erase _nami_jj
        return
    end

    if test "$workspace_root" != "$previous_root"; or not set --query _nami_jj
        set --global _nami_jj querying
    end

    _nami_start_jj_worker "$workspace_root"
end

function _nami_on_pwd --on-variable PWD
    set --query _nami_refresh_deferred; and return

    _nami_refresh
    commandline --function repaint 2>/dev/null
end

function _nami_uninstall --on-event nami_uninstall
    _nami_stop_jj_worker

    for variable in (set --names | string match '_nami_*')
        set --erase "$variable"
    end

    set --local private_functions (functions --all | string match '_nami_*')
    set --query private_functions[1]; and functions --erase $private_functions
end
