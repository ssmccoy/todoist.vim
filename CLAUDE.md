# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A pure vim9script Todoist client plugin for Vim 9.0+. No build step — only requires Vim and `curl`. Uses Todoist REST API v1 (`https://api.todoist.com/api/v1`) with cursor-based pagination, and the Sync API v1 for reorder/move operations.

## Commands

**Run all tests:**
```bash
bash test/run.sh
```

**Run a single test file:**
```bash
vim -u NONE -N -es \
  --cmd "let g:test_file='test/test_dates.vim'" \
  --cmd "let g:test_output_file='/dev/stdout'" \
  --cmd "set rtp+=$(pwd)" \
  -S test/runner.vim
```

Tests use Vim's built-in `assert_equal`/`assert_true`/`assert_false` functions. Test functions must be `def g:Test_*()` (global, capitalized prefix) for discovery via `getcompletion()`. Tests run in headless Vim (`vim -es`), results written to a file specified by `g:test_output_file`.

## Architecture

**Entry point chain:** `plugin/todoist.vim` → `:Todoist` command → `autoload/todoist.vim` (bridge) → `main.vim`

**Module roles:**
- `main.vim` — Controller: buffer lifecycle, keybindings, action handlers, async refresh loop
- `api.vim` — HTTP client: wraps curl via `compat.RunJob()`, handles paginated GET with `PaginatedGet()`, extracts HTTP status codes from curl `-w` output
- `compat.vim` — Abstraction layer: `RunJob()` for async jobs, text property management for highlighting, buffer line operations. Contains a test hook (`g:Todoist_test_run_job`) for mocking HTTP in tests
- `render.vim` — Builds buffer content as lists of `{hl: string, text: string}` parts, applies via text properties. The task list buffer is `nomodifiable`; render functions toggle it temporarily
- `detail.vim` — Task detail view: formats task→buffer lines, parses buffer→API params. Uses `buftype=acwrite` with `BufWriteCmd` for `:w` to save via API
- `state.vim` — Single global state dict + options with deep merge
- `models.vim` — Builds parent-child tree from flat task list, sorts by `child_order`, flattens with depth annotation
- `dates.vim`, `colors.vim` — Pure utility functions, no imports

**Async pattern:** All API calls use callbacks `(ok: bool, data: any) => void`. Callbacks are deferred with `timer_start(0, ...)` to ensure they fire in the Vim event loop. The task list buffer is `nomodifiable`, so render operations wrap writes in `setbufvar(bufnr, '&modifiable', 1/0)`.

**API v1 specifics:** IDs are strings (not numbers) — never use `string()` on them (it adds quotes). Paginated endpoints return `{"results": [...], "next_cursor": ...}`. HTTP errors are detected via `-w '\n%{http_code}'` appended to curl output, parsed in `DoRequest()`.

**Priority mapping:** Display uses p1(highest)–p4(lowest), API uses 4(highest)–1(lowest). Conversion in `detail.vim`: `PriorityToApi()`/`PriorityFromApi()`.

**Two buffer types:**
1. `filetype=todoist` — Task list (nomodifiable, keybinding-driven)
2. `filetype=todoist-task` — Task detail view (editable, `:w` saves to API, `q` closes)
