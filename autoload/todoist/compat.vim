vim9script

# Buffer operations and highlight abstraction for todoist.vim
# Uses Vim 9 text properties for highlighting

# Track registered prop types per buffer
var registered_props: dict<dict<bool>> = {}

# --- Text Property Infrastructure ---

# Ensure a text property type is registered for a highlight group
def EnsurePropType(bufnr: number, hlgroup: string)
  var bufkey = string(bufnr)
  if !has_key(registered_props, bufkey)
    registered_props[bufkey] = {}
  endif
  var prop_name = 'todoist_' .. hlgroup
  if !has_key(registered_props[bufkey], prop_name)
    prop_type_add(prop_name, {highlight: hlgroup, bufnr: bufnr})
    registered_props[bufkey][prop_name] = true
  endif
enddef

# --- Buffer Text Operations ---

export def BufSetLines(bufnr: number, start: number, end_: number, lines: list<string>)
  if end_ == -1 && start == 0
    # Full buffer replace
    deletebufline(bufnr, 1, '$')
    if !empty(lines)
      setbufline(bufnr, 1, lines)
    endif
  elseif end_ == -1
    # Replace from start to end of buffer
    deletebufline(bufnr, start + 1, '$')
    if !empty(lines)
      appendbufline(bufnr, start, lines)
    endif
  else
    # Replace specific range (start/end are 0-indexed)
    if end_ > start
      deletebufline(bufnr, start + 1, end_)
    endif
    if !empty(lines)
      if start == 0
        setbufline(bufnr, 1, lines)
      else
        appendbufline(bufnr, start, lines)
      endif
    endif
  endif
enddef

# --- Highlighting ---

# Namespace sentinel (Vim uses prop types, not namespaces)
var namespace_id: number = 0

export def GetNamespace(): number
  return namespace_id
enddef

export def AddHighlight(bufnr: number, ns: number, hlgroup: string, line: number, col_start: number, col_end: number)
  if empty(hlgroup) || hlgroup == 'Normal'
    return
  endif
  EnsurePropType(bufnr, hlgroup)
  var length = col_end - col_start
  if length > 0
    prop_add(line + 1, col_start + 1, {
      type: 'todoist_' .. hlgroup,
      length: length,
      bufnr: bufnr,
    })
  endif
enddef

export def ClearHighlights(bufnr: number, ns: number, start: number, end_: number)
  var last_line = end_ == -1 ? getbufinfo(bufnr)[0].linecount : end_
  var lnum = start + 1
  while lnum <= last_line
    prop_clear(lnum, lnum, {bufnr: bufnr})
    lnum += 1
  endwhile
enddef

# Clean up prop types when buffer is wiped
export def CleanupBuffer(bufnr: number)
  var bufkey = string(bufnr)
  if has_key(registered_props, bufkey)
    for prop_name in keys(registered_props[bufkey])
      silent! prop_type_delete(prop_name, {bufnr: bufnr})
    endfor
    remove(registered_props, bufkey)
  endif
enddef

# --- Async Jobs ---

# OnStdout: (data: list<string>) => void
# OnExit: (exit_code: number) => void
export def RunJob(cmd: list<string>, OnStdout: func(list<string>), OnExit: func(number)): job
  if exists('g:Todoist_test_run_job')
    return g:Todoist_test_run_job(cmd, OnStdout, OnExit)
  endif
  var exit_code_val = -1
  var channel_closed = false
  var Finish = () => {
    if channel_closed && exit_code_val != -1
      OnExit(exit_code_val)
    endif
  }

  return job_start(cmd, {
    out_cb: (ch: channel, msg: string) => {
      OnStdout([msg])
    },
    err_cb: (ch: channel, msg: string) => {
      OnStdout([msg])
    },
    close_cb: (ch: channel) => {
      channel_closed = true
      Finish()
    },
    exit_cb: (j: job, code: number) => {
      exit_code_val = code
      Finish()
    },
  })
enddef
