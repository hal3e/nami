set project_root (path resolve (path dirname (status filename))/..)
set --prepend fish_function_path "$project_root/functions"
set temp_root (command mktemp -d)
set workspace "$temp_root/workspace"
set nested_workspace "$workspace/nested"
set outside "$temp_root/outside"

mkdir -p "$workspace/.jj" "$nested_workspace/.jj" "$nested_workspace/child" "$outside"

@echo '=== jj root discovery ==='

@test 'given workspace root, when discovered, then marker directory is returned' \
    (_nami_find_jj_root "$workspace") = "$workspace"
@test 'given nested workspace, when discovered, then closest marker directory wins' \
    (_nami_find_jj_root "$nested_workspace/child") = "$nested_workspace"
@test 'given directory outside workspace, when discovered, then no root is returned' (
    _nami_find_jj_root "$outside" >/dev/null
    echo $status
) -eq 1

rm -rf "$temp_root"
