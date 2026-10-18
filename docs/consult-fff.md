# Indexed fuzzy file search with Consult and Nushell

`consult-fff` and `consult-fff-grep` use [Nushell's FFF-backed `idx` commands](https://www.nushell.sh/commands/docs/idx.html)
in a persistent subprocess. Each search directory gets an in-memory index and
filesystem watcher. Emacs sends queries over a pipe and receives JSON filenames
or content matches. Indexing, matching, and ranking run outside Emacs. Emacs adds display
highlighting to the returned candidates.

## Usage

| Command/key | Scope |
| --- | --- |
| `SPC s f` | Current Projectile project, otherwise current directory |
| `SPC s F` | Current directory, including when inside a project |
| `SPC s g` / `M-x consult-fff-grep` | Literal content search in the current project/directory |
| `SPC s G` / `M-x consult-fff-grep-fuzzy` | Typo-tolerant content search |
| `M-x consult-fff-grep-regexp` | Content search with Rust regex syntax |
| Prefix argument before a search command | Prompt for a directory |
| `M-x consult-fff` | Current Emacs project, otherwise current directory |
| `M-x consult-fff-stop` | Release all cached indexes and watchers |

For an existing Emacs session, evaluate `(load "consult-fff")` and then
`(load "project-config")` to load the commands and keybindings. Incompatible
cached workers are replaced automatically on their next use. Restarting Emacs
also loads the changes.

Type normally at the Consult `#` prompt. For example, `porject` or `prjcfg` can
find `project-config.el`. Consult sends the query before a second `#` to FFF;
anything after the second `#` uses your existing Emacs completion styles as an
additional filter. This prevents Prescient/Orderless from rejecting FFF's typo
matches. Backend relevance order is preserved. Consult file preview and normal
file-category actions remain available.

Matching letters use the theme's `consult-highlight-match` face. Filename highlighting
handles literal matches, abbreviations, missing letters, substitutions, and
adjacent swapped letters. Nushell 0.114.1 does not return matched-character
positions, even with `idx find --verbose`, so Emacs computes an approximate
alignment for display; FFF still determines results and ranking. Negated/glob
constraints are not highlighted as fuzzy query terms. Very large alignments
are skipped to bound the work done in Emacs.

Content results show `file:line:text`, support Consult preview, and jump to the
matched line and column with RET. Unlike filename search, `idx search` supplies
match ranges; these are converted from UTF-8 bytes to Emacs character positions
for highlighting and navigation. Literal mode treats regex punctuation as text.
Regex mode accepts Rust regex syntax, rather than Emacs regexp escaping. Fuzzy
mode enables approximate matching within lines. `#query#filter` works in every
mode. Use `consult-fff-max-results` to change the maximum returned matching lines.

The default returns the best 200 matches. Refine the query to reach other files,
or change `consult-fff-max-results`. Three directories stay warm by default;
unused workers expire after 15 minutes. Customize `consult-fff-max-processes`
and `consult-fff-idle-timeout` to change those limits. Stop the workers to force
a fresh scan after changing ignore rules.

The lifecycle for each directory is:

1. First use starts a Nu worker and builds its index asynchronously.
2. Filename and content searches, additional queries, and reopened pickers reuse
   that same worker and index.
3. The filesystem watcher updates the index incrementally as files change.
4. Quitting Emacs, stopping workers, 15 minutes of inactivity, or eviction from
   the three-directory cache releases the index. The next use builds it again.

Closing the picker alone does not unload its index. There is no on-disk file
index reused across Emacs restarts. The Nix GC root retains the Nushell program;
it does not retain indexed repository data.

Both path and content indexing are enabled in each worker. Content indexing
adds startup work and memory compared with the original filename-only version;
the watcher keeps searchable content updated. Indexed content follows FFF's file
eligibility and ignore rules. Ripgrep remains available as `M-x consult-ripgrep`.
Only local directories are supported. The helper uses `/dev/stdin`, so it targets
Unix systems.

## Nushell dependency

The active shell on this machine is Nushell 0.112.2, which has no `idx` command.
Nushell 0.114.1 was already installed in the Nix store. A GC root at
`var/consult-fff/nushell` retains it for this plugin; the default shell and Home
Manager configuration are unchanged. `var/` is ignored by Git.

On a fresh checkout, install a Nushell version with `idx init`, `idx find`,
`idx search`, and filesystem watching, then set the executable if necessary:

```elisp
(setq consult-fff-nushell-command "/path/to/nu")
```

The default uses the local GC root if present, otherwise `nu` on Emacs's PATH.
Version 0.114.1 was tested. In Home Manager, a newer `pkgs-unstable.nushell` can
provide this dependency. The Nixpkgs package named `fff` is the unrelated
[dylanaraps terminal file manager](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/ff/fff/package.nix).
There is no separate FFF executable, Python package, or Emacs native module
required by this integration.

The helper runs without shell configuration or history. Queries and paths travel
as JSON, rather than shell code. Errors appear in `*consult-fff-log*`.

## Options evaluated

| Option | Fit for this use |
| --- | --- |
| [JonasThowsen/fff.el](https://github.com/JonasThowsen/fff.el) | Already integrates FFF with Consult. Its current implementation uses `emacs-ffi`, synchronous native searches via `consult--async-dynamic`, a scan-wait loop up to ten seconds, and one cached project instance. It also declares an older C creation signature. A persistent worker is a suitable way to make this design asynchronous. |
| [FFF](https://github.com/dmtrKovalenko/fff) through Nushell | Chosen. Typo-tolerant path ranking, index reuse, live updates, structured output, and a dependency already installed locally. One long-lived Nu process per root preserves the warm index. |
| [dsearch](https://github.com/AvengeMedia/danksearch) | Good candidate for an existing, system-wide persistent index with filename/content search and fuzzy queries. Its local index contains 36,798 documents, but excludes hidden paths and has a maximum depth of six. Actual queries scoped to `.emacs.d` returned no files. It would require index configuration changes for complete project coverage. |
| [Affe](https://github.com/minad/affe) | Existing Consult-based asynchronous fuzzy finder, already configured here. It still needs a directory listing, rather than retaining a live filesystem index. |
| [fzfa](https://github.com/jojojames/fzfa), `fd` + `fzf`, `consult-locate` | Useful alternatives for async matching or indexed enumeration. They need additional machinery to combine live indexing, directory scope, and typo-tolerant ranking. Fuzzy subsequence matching alone cannot handle every misspelling. |

FFF retains its file index in memory for the worker's lifetime. The cold scan
still happens after restarting/evicting a worker. This is different from
dsearch's on-disk index. Opening another terminal does not expose that shell's
live index to Emacs. Starting `nu -c 'idx init ...'` for every query would lose
the principal benefit. Nushell documents this lifetime in
[its discussion of `idx`](https://github.com/nushell/nushell/discussions/18288),
and [the persistence issue](https://github.com/nushell/nushell/issues/18929)
explains why an external caller should keep the process alive.

The official FFF 0.11.0 Python bindings were also tested successfully before
switching to Nushell. They are an alternative worker backend if needed later.

## Validation

Fourteen ERT tests cover real worker searches, typo matching, warm
reuse, Unicode/quoted/newline filenames, directory scope, watcher additions and
deletions, partial JSON messages, stale/cancelled results, idle/LRU cleanup,
worker restart, remote-directory rejection, display highlighting, all three
content modes, content updates, and Unicode match positioning. Run from the
repository root:

```sh
emacs -Q --batch \
  -L straight/build/compat -L straight/build/consult -L lisp \
  -l tests/consult-fff-tests.el -f ert-run-tests-batch-and-exit
```

A terminal Emacs session with Vertico, Prescient, and Orderless also verified
that `porject` presents `project-config.el`, highlights the matched letters,
previews it, and opens it with RET.

Before content indexing was enabled, the filename-only worker measured the
following on a synthetic tree of 100,001 empty files. These figures are not
content-search benchmarks:

| Measurement | Result |
| --- | ---: |
| Start worker and complete initial index | 128.72 ms |
| Warm `porject` query, median of 20 | 4.45 ms |
| Slowest of those queries | 6.46 ms |
| `fd` exact `project-config` search, median of 5 | 17.45 ms |
| Worker resident memory | About 48 MiB |

These backend query timings include JSON and pipe transport. They exclude
Emacs display highlighting and Consult's 50 ms throttle / 30 ms debounce.
The `fd` measurement uses an exact query and does not perform fuzzy ranking.
Real repositories and storage will differ.
