# Nami

Nami is a fast, single-line [Fish](https://fishshell.com/) prompt focused on [Jujutsu](https://www.jj-vcs.dev/) workspaces. It is derived from [Hydro](https://github.com/jorgebucaran/hydro), with Git-specific behavior replaced by an asynchronous, non-integrating JJ query.

## Install

Requirements:

- Linux
- Fish 4.0 or newer
- JJ 0.41 or newer
- [Fisher](https://github.com/jorgebucaran/fisher)

``` fish
fisher install hal3e/nami
```

When a JJ query fails, Nami emits one warning, hides the JJ segment, and retries at the next prompt or directory change.

## Prompt

Nami renders these segments on one line:

``` text
<mode> <path> <change-id> <duration> <pipeline-status> >
```

- Path components are shortened, while the JJ workspace name and current directory remain readable.
- JJ displays only `change_id.shortest().prefix()`.
- Command duration appears after the configured threshold.
- Any failed pipeline displays every pipeline status and colors the prompt as an error.
- Vi bindings use fixed lowercase `i`, `n`, `r`, and `v` mode indicators.

JJ state is encoded without adding prompt noise. Precedence runs top to bottom:

| State               | Default | Rendering          |
| ------------------- | ------- | ------------------ |
| Conflict            | red     | change ID          |
| Divergent           | red     | change ID plus `≠` |
| Empty               | green   | change ID          |
| Missing description | yellow  | change ID          |
| Normal              | blue    | change ID          |


An empty, undescribed change is green because empty state has higher precedence than missing-description state.

## Async JJ Query

Nami discovers the nearest `.jj/` ancestor synchronously with Fish builtins, so the workspace name is available before the first prompt render. Nami runs JJ directly in the background and repaints when the newest result arrives.

Nami runs at most one worker. Each new prompt replaces any pending query with a fresh query. Directory-history bindings refresh the path and query immediately. During the initial query, Nami reserves one blank change-ID character so a typical one-character result does not move the prompt symbol.

Nami does not time out a query while the shell is idle. A pending query is stopped before the next prompt query, idle directory refresh, shell exit, or uninstall. Missing or unsupported JJ and query failures share one failure path: warn once, hide the segment for that refresh, and retry later.

The worker receives the discovered root and runs one `jj --no-integrate-operation` log query. This provides current working-copy state without advancing JJ's operation head. JJ still creates unintegrated snapshot operations and objects internally; Nami does not fetch, inspect remotes, or integrate those prompt operations.

Nami configuration loads at shell startup. Manually re-sourcing `conf.d/nami.fish` while a query is active is unsupported; restart Fish after updating Nami.

## Configuration

Set variables globally in `config.fish`, or universally from the command line for future shells:

``` fish
set --global nami_color_jj cyan
set --global nami_cmd_duration_threshold 2000

# Persistent; restart the current shell after setting.
set --universal nami_ignored_jj_paths /work/large-repo /work/archive
```

Colors accept any arguments supported by `set_color`. Numeric settings must be non-negative integers. Invalid values emit one warning per setting and use the documented default.

| Variable                       | Default              | Purpose                       |
| ------------------------------ | -------------------- | ----------------------------- |
| `nami_color_pwd`               | `$fish_color_normal` | Path color                    |
| `nami_color_jj`                | `blue`               | Normal JJ color               |
| `nami_color_jj_empty`          | `green`              | Empty-change color            |
| `nami_color_jj_no_description` | `yellow`             | Missing-description color     |
| `nami_color_jj_conflict`       | `red`                | Conflict color                |
| `nami_color_jj_divergent`      | `red`                | Divergence color              |
| `nami_color_start`             | `$fish_color_normal` | Start-symbol color            |
| `nami_color_prompt`            | `$fish_color_normal` | Prompt-symbol color           |
| `nami_color_duration`          | `$fish_color_normal` | Duration color                |
| `nami_color_error`             | `$fish_color_error`  | Error and failed-prompt color |


| Variable                      | Default | Purpose                                                           |
| ----------------------------- | ------- | ----------------------------------------------------------------- |
| `nami_symbol_start`           | empty   | Prefix before path                                                |
| `nami_symbol_prompt`          | `>`     | Prompt symbol                                                     |
| `nami_symbol_jj_divergent`    | `≠`     | Divergence suffix                                                 |
| `fish_prompt_pwd_dir_length`  | `1`     | Shortened path component length; `0` shows only current directory |
| `nami_cmd_duration_threshold` | `1000`  | Minimum displayed duration in milliseconds                        |
| `nami_ignored_jj_paths`       | empty   | Exact JJ workspace roots whose JJ segment is hidden               |


Use `jj root` to obtain an exact workspace root for `nami_ignored_jj_paths`.

## Development

Tests use [Fishtape](https://github.com/jorgebucaran/fishtape):

``` fish
fish --no-execute conf.d/nami.fish functions/*.fish tests/*.fish tests/helpers/*.fish tests/scenarios/*.fish
fishtape tests/*.fish
```

## License

[MIT](LICENSE.md). Hydro-derived portions retain their original copyright notice.
