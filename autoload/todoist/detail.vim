vim9script

# Task detail view for todoist.vim
# Format, parse, and manage the detail buffer for viewing/editing tasks

import './api.vim' as api
import './comments.vim' as comments
import './state.vim' as S

# --- Priority mapping ---
# Display: p1=highest(red) p2 p3 p4=lowest — API: 4=highest 3 2 1=lowest

export def PriorityToApi(display: string): number
  var map = {'p1': 4, 'p2': 3, 'p3': 2, 'p4': 1}
  return get(map, display, 1)
enddef

export def PriorityFromApi(api_val: any): string
  var n = type(api_val) == v:t_string ? str2nr(api_val) : api_val
  var map = {4: 'p1', 3: 'p2', 2: 'p3', 1: 'p4'}
  return get(map, n, 'p4')
enddef

# --- Project resolution ---

export def ResolveProjectName(project_id: string): string
  for p in S.state.projects
    if get(p, 'id', '') == project_id
      return get(p, 'name', '')
    endif
  endfor
  return S.state.current_project_name
enddef

export def ResolveProjectId(project_name: string): string
  for p in S.state.projects
    if get(p, 'name', '') == project_name
      return get(p, 'id', '')
    endif
  endfor
  return get(S.state.current_project, 'id', '')
enddef

# --- Format task → buffer lines ---

export def FormatTask(item: dict<any>): list<string>
  var lines: list<string> = []

  # Line 1: title
  add(lines, '# ' .. get(item, 'content', ''))

  # Line 2: dense core fields
  var project_name = ResolveProjectName(get(item, 'project_id', ''))
  var pri = PriorityFromApi(get(item, 'priority', 1))
  var due = get(item, 'due', v:null)
  var due_str = ''
  if type(due) == v:t_dict
    due_str = get(due, 'string', get(due, 'date', ''))
  endif
  add(lines, 'Project: ' .. project_name .. ' | Pri: ' .. pri .. ' | Due: ' .. due_str)

  # Optional fields (only if non-empty)
  var labels = get(item, 'labels', [])
  if !empty(labels)
    add(lines, 'Labels: ' .. join(labels, ', '))
  endif

  var parent_id = get(item, 'parent_id', v:null)
  if type(parent_id) == v:t_string && !empty(parent_id)
    # Try to resolve parent name from items
    var parent_name = parent_id
    for other in S.state.items
      if get(other, 'id', '') == parent_id
        parent_name = get(other, 'content', parent_id)
        break
      endif
    endfor
    add(lines, 'Parent: ' .. parent_name)
  endif

  # Blank separator
  add(lines, '')

  # Description body
  var desc = get(item, 'description', '')
  if !empty(desc)
    lines += split(desc, "\n")
  endif

  return lines
enddef

export def FormatNewTask(): list<string>
  var project_name = S.state.current_project_name
  return ['# ', 'Project: ' .. project_name .. ' | Pri: p4 | Due: ', '']
enddef

# --- Parse buffer lines → API params ---

export def ParseBuffer(lines: list<string>): dict<any>
  var params: dict<any> = {}

  if empty(lines)
    return params
  endif

  # Line 1: title
  if lines[0] =~ '^# '
    params.content = lines[0][2 :]
  endif

  # Line 2: dense core fields
  if len(lines) > 1
    var meta = lines[1]
    var parts = split(meta, ' | ')
    for part in parts
      var kv = matchlist(part, '^\(\w\+\): \?\(.*\)$')
      if empty(kv)
        continue
      endif
      var key = kv[1]
      var val = kv[2]
      if key == 'Project'
        params.project_id = ResolveProjectId(val)
      elseif key == 'Pri'
        params.priority = PriorityToApi(val)
      elseif key == 'Due'
        if !empty(val)
          params.due_string = val
        endif
      endif
    endfor
  endif

  # Lines 3+: optional fields until blank line
  var body_start = len(lines)
  var i = 2
  while i < len(lines)
    var line = lines[i]
    if empty(line)
      body_start = i + 1
      break
    endif
    var kv = matchlist(line, '^\(\w\+\): \?\(.*\)$')
    if !empty(kv)
      var key = kv[1]
      var val = kv[2]
      if key == 'Labels'
        if !empty(val)
          params.labels = split(val, ', ')
        else
          params.labels = []
        endif
      endif
      # Parent is not sent back to API (parent_id changes require MoveTask)
    endif
    i += 1
  endwhile

  # Everything after blank line until comments sentinel: description
  var body_end = len(lines)
  var j = body_start
  while j < len(lines)
    if lines[j] == '--- Comments ---'
      body_end = j
      break
    endif
    j += 1
  endwhile

  if body_start < body_end
    params.description = join(lines[body_start : body_end - 1], "\n")
  else
    params.description = ''
  endif

  return params
enddef

# --- Buffer management ---

export def OpenDetailBuffer(item: dict<any>)
  var lines = FormatTask(item)
  var task_id = get(item, 'id', '')
  SetupDetailBuffer(lines, task_id)
  if !empty(task_id)
    LoadComments(task_id)
  endif
enddef

export def OpenNewTaskBuffer()
  var lines = FormatNewTask()
  SetupDetailBuffer(lines, '')
enddef

def SetupDetailBuffer(lines: list<string>, task_id: string)
  belowright new

  if !empty(task_id)
    execute 'file Todoist:' .. task_id
  else
    file Todoist:new
  endif

  setlocal filetype=todoist-task
  setlocal buftype=acwrite
  setlocal bufhidden=wipe
  setlocal noswapfile

  b:todoist_task_id = task_id
  b:todoist_is_new = empty(task_id)

  setline(1, lines)
  setlocal nomodified

  if empty(task_id)
    cursor(1, 3)
    startinsert!
  else
    normal! gg
  endif

  augroup TodoistDetail
    autocmd! * <buffer>
    autocmd BufWriteCmd <buffer> call todoist#detail#SaveBuffer()
  augroup END

  nnoremap <buffer><silent> q  <Cmd>bwipe!<CR>
  nnoremap <buffer><silent> C  <ScriptCmd>OnDetailShowCommentHistory()<CR>
  nnoremap <buffer><silent> ca <ScriptCmd>OnDetailAddComment()<CR>
enddef

def OnDetailShowCommentHistory()
  var task_id = b:todoist_task_id
  if empty(task_id)
    echomsg 'Todoist: Save the task first'
    return
  endif
  comments.ShowCommentHistory({'id': task_id, 'content': getline(1)[2 :]})
enddef

def OnDetailAddComment()
  var task_id = b:todoist_task_id
  if empty(task_id)
    echomsg 'Todoist: Save the task first'
    return
  endif
  comments.AddComment(task_id, getline(1)[2 :])
enddef

def LoadComments(task_id: string)
  var bufnr = bufnr('%')
  api.GetComments(task_id, (ok: bool, data: any) => {
    if !bufexists(bufnr)
      return
    endif
    if !ok || empty(data)
      return
    endif
    var lines = ['--- Comments ---'] + comments.FormatCommentLines(data)
    setbufvar(bufnr, '&modified', 0)
    var was_modifiable = getbufvar(bufnr, '&modifiable')
    appendbufline(bufnr, '$', lines)
    setbufvar(bufnr, '&modified', 0)
  })
enddef

export def SaveBuffer()
  var buflines = getline(1, '$')
  var params = ParseBuffer(buflines)
  var task_id = b:todoist_task_id
  var bufnr = bufnr('%')

  if empty(get(params, 'content', ''))
    echoerr 'Task content cannot be empty'
    return
  endif

  # Mark saved immediately so :wq / ZZ can close the buffer
  setlocal nomodified

  if b:todoist_is_new
    api.AddTask(params, (ok: bool, result: any) => {
      if !bufexists(bufnr)
        return
      endif
      if !ok
        setbufvar(bufnr, '&modified', 1)
        echoerr 'Todoist: Failed to create task'
        return
      endif
      setbufvar(bufnr, 'todoist_task_id', result.id)
      setbufvar(bufnr, 'todoist_is_new', false)
      echomsg 'Todoist: Task created'
    })
  else
    api.UpdateTask(task_id, params, (ok: bool, result: any) => {
      if !bufexists(bufnr)
        return
      endif
      if !ok
        setbufvar(bufnr, '&modified', 1)
        echoerr 'Todoist: Failed to update task'
        return
      endif
      echomsg 'Todoist: Task updated'
    })
  endif
enddef
