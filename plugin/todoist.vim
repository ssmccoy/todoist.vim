vim9script

# todoist.vim — Todoist integration for Vim
# Requires Vim 9.0+ with vim9script support

import autoload 'todoist.vim' as todoist

# --- Commands ---

def CompleteProjects(ArgLead: string, CmdLine: string, CursorPos: number): list<string>
  return todoist.CompleteProjects(ArgLead, CmdLine, CursorPos)
enddef

command! -nargs=? -complete=customlist,s:CompleteProjects Todoist todoist.Open(<q-args>)

# --- Highlights ---

def SetHighlight(name: string, fg: string = '', bg: string = '', attr: string = '')
  if hlexists(name)
    return
  endif

  var cmd = 'hi! ' .. name
  if !empty(fg)
    cmd ..= ' guifg=' .. fg
  endif
  if !empty(bg)
    cmd ..= ' guibg=' .. bg
  endif
  if !empty(attr)
    cmd ..= ' gui=' .. attr
  endif
  execute cmd
enddef

SetHighlight('todoistTitle',            'white', '#e84644', 'bold')
SetHighlight('todoistDateOverdue',      '#FF6D6D')
SetHighlight('todoistDateToday',        '#52E054')
SetHighlight('todoistDateTomorrow',     '#ff8700')
SetHighlight('todoistDateThisWeek',     '#A873FC')
SetHighlight('todoistPri1',             '#D1453B')
SetHighlight('todoistPri2',             '#EB8909')
SetHighlight('todoistPri3',             '#246FE0')
SetHighlight('todoistContent',          '',      '',        'bold')
SetHighlight('todoistContentCompleted', '',      '',        'strikethrough')

hi def link todoistCheckbox    Delimiter
hi def link todoistDate        Comment
hi def link todoistSeparator   Normal

# Task detail view highlights
hi def link todoistTaskTitle       todoistTitle
hi def link todoistTaskTitleMarker Delimiter
hi def link todoistTaskKeyName     Type
hi def link todoistTaskMetaSep     Delimiter
hi def link todoistTaskOptional    Normal
hi def link todoistTaskPri1        todoistPri1
hi def link todoistTaskPri2        todoistPri2
hi def link todoistTaskPri3        todoistPri3

# Comment view highlights
hi def link todoistCommentTitle  todoistTitle
hi def link todoistCommentSep    Delimiter

hi def link todoistErrorIcon      ErrorMsg
hi def link todoistErrorMessage   ErrorMsg
hi def link todoistWarningMessage WarningMsg
hi def link todoistMessage        Comment

# --- Clap provider ---

g:clap_provider_todoist = {
  'source': () => todoist.ListProjects(),
  'sink': 'Todoist',
}
