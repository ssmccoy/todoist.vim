vim9script

# Main controller for todoist.vim
# Port of src/index.js — entry point, action handlers, buffer management

import './api.vim' as api
import './comments.vim' as comments
import './compat.vim' as compat
import './colors.vim' as colors
import './detail.vim' as detail
import './models.vim' as models
import './render.vim' as render
import './state.vim' as S

var did_setup: bool = false

# Mappings use <ScriptCmd> to resolve functions in this script's context
def SetupMappings()
  nnoremap <buffer><silent> O    <ScriptCmd>OnCreate(-1)<CR>
  nnoremap <buffer><silent> o    <ScriptCmd>OnCreate(+1)<CR>
  nnoremap <buffer><silent> x    <ScriptCmd>OnComplete()<CR>
  nnoremap <buffer><silent> DD   <ScriptCmd>OnDelete()<CR>
  nnoremap <buffer><silent> <    <ScriptCmd>OnUnindent()<CR>
  nnoremap <buffer><silent> >    <ScriptCmd>OnIndent()<CR>
  nnoremap <buffer><silent> cc   <ScriptCmd>OnChangeContent()<CR>
  nnoremap <buffer><silent> cd   <ScriptCmd>OnChangeDate()<CR>
  nnoremap <buffer><silent> r    <ScriptCmd>OnRefresh()<CR>
  nnoremap <buffer><silent> pdd  <ScriptCmd>OnProjectArchive()<CR>
  nnoremap <buffer><silent> pDD  <ScriptCmd>OnProjectDelete()<CR>
  nnoremap <buffer><silent> pcc  <ScriptCmd>OnProjectChangeColor()<CR>
  nnoremap <buffer><silent> pcn  <ScriptCmd>OnProjectChangeName()<CR>
  nnoremap <buffer><silent> p4   <ScriptCmd>OnChangePriority(1)<CR>
  nnoremap <buffer><silent> p3   <ScriptCmd>OnChangePriority(2)<CR>
  nnoremap <buffer><silent> p2   <ScriptCmd>OnChangePriority(3)<CR>
  nnoremap <buffer><silent> p1   <ScriptCmd>OnChangePriority(4)<CR>
  nnoremap <buffer><silent> <CR> <ScriptCmd>OnOpenDetail()<CR>
  nnoremap <buffer><silent> A    <ScriptCmd>OnCreateDetailed()<CR>
  nnoremap <buffer><silent> C    <ScriptCmd>OnShowCommentHistory()<CR>
  nnoremap <buffer><silent> ca   <ScriptCmd>OnAddComment()<CR>
enddef

# --- API key resolution ---

def GetApiKey(): string
  S.LoadOptions()
  var key = S.state.options.key
  if empty(key)
    key = $TODOIST_API_KEY
  endif
  return key
enddef

# --- Entry point ---

export def Open(project_name: string = '')
  var key = GetApiKey()

  S.state.is_loading = empty(key) ? false : true
  S.state.current_project_name = empty(project_name) ? S.state.options.defaultProject : project_name

  if empty(key)
    SetError([
      "Couldn't find API key: define it in your .profile or .bashrc:",
      '  export TODOIST_API_KEY=xxxxxxxx',
    ])
  endif

  CreateBuffer()

  if !empty(key)
    api.Setup(key)
    if !did_setup
      colors.SetupHighlights()
      did_setup = true
    endif
    Refresh(true)
  else
    render.Full()
  endif
enddef

# --- Buffer management ---

def CreateBuffer()
  var existing = bufnr('Todoist')
  if existing != -1
    var winid = bufwinid(existing)
    if winid != -1
      win_gotoid(winid)
    else
      execute 'sbuffer ' .. existing
    endif
  else
    new
    file Todoist
  endif

  setlocal filetype=todoist
  setlocal buflisted
  setlocal buftype=nofile
  setlocal nomodifiable
  setlocal nolist
  setlocal nonumber
  setlocal signcolumn=no
  setlocal conceallevel=2

  SetupMappings()

  S.state.buffer_id = bufnr('%')
  render.Full()
  normal! 3gg
enddef

# --- Refresh / Redraw ---

def Redraw(loading: bool = false)
  if loading
    S.state.is_loading = true
  endif
  render.Full()
enddef

def Refresh(create: bool = false)
  api.GetProjects((ok: bool, projects: any) => {
    if !ok
      SetError(['Failed to fetch projects'])
      S.state.is_loading = false
      render.Full()
      return
    endif

    S.state.projects = projects

    # Find current project
    var found_project: dict<any> = {}
    for p in projects
      if get(p, 'name', '') == S.state.current_project_name
        found_project = p
        break
      endif
    endfor

    if empty(found_project) && create
      # Create the project
      api.AddProject({'name': S.state.current_project_name}, (ok2: bool, new_project: any) => {
        if !ok2
          SetError(['Failed to create project'])
          S.state.is_loading = false
          render.Full()
          return
        endif
        S.state.current_project = new_project
        FetchTasks()
      })
    elseif empty(found_project)
      # Fallback to first project
      if !empty(projects)
        found_project = projects[0]
      endif
      S.state.current_project = found_project
      S.state.current_project_name = get(found_project, 'name', '')
      FetchTasks()
    else
      S.state.current_project = found_project
      FetchTasks()
    endif
  })
enddef

def FetchTasks()
  var project_id = get(S.state.current_project, 'id', '')
  if empty(project_id)
    S.state.items = []
    S.state.is_loading = false
    ClearError()
    render.Full()
    return
  endif

  api.GetTasks(project_id, (ok: bool, tasks: any) => {
    if !ok
      SetError(['Failed to fetch tasks', string(tasks)])
      S.state.is_loading = false
      render.Full()
      return
    endif

    S.state.items = models.ProcessItems(tasks)
    S.state.is_loading = false
    ClearError()
    render.Full()
  })
enddef

# --- Helpers ---

def GetCurrentItemIndex(): number
  var line_nr = line('.') - 1  # 0-indexed
  return render.LineToItemIndex(line_nr)
enddef

def SetError(messages: list<string>)
  S.state.error_message = messages
  ShowErrorMessage(messages)
enddef

def ClearError()
  S.state.error_message = []
enddef

def ShowErrorMessage(lines: list<string>)
  echohl todoistErrorMessage
  for msg in lines
    echomsg 'Todoist: ' .. msg
  endfor
  echohl Normal
enddef

def InputPrompt(hl: string, prompt: string, default_text: string = ''): string
  execute 'echohl ' .. hl
  var result: string
  try
    if empty(default_text)
      result = input(prompt)
    else
      result = input(prompt, default_text)
    endif
  catch
    # Ctrl-C interrupt
    result = ''
  endtry
  echohl Normal
  return result
enddef

# --- Action handlers ---

export def OnRefresh()
  Redraw(true)
  Refresh()
enddef

export def OnOpenDetail()
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  detail.OpenDetailBuffer(S.state.items[index])
enddef

export def OnCreateDetailed()
  detail.OpenNewTaskBuffer()
enddef

export def OnCreate(direction: number)
  var index = GetCurrentItemIndex()
  var next_index = index + direction
  var max_index = len(S.state.items) - 1
  var current_item = index >= 0 && index <= max_index ? S.state.items[index] : {'child_order': 0, 'order': 0}
  if next_index < 0
    next_index = 0
  elseif next_index > max_index
    next_index = max_index
  endif
  var next_item = next_index >= 0 && next_index <= max_index ? S.state.items[next_index] : {'parent_id': v:null}

  var content = InputPrompt('Question', 'Content: ')
  if empty(content)
    return
  endif

  var due_date = InputPrompt('Question', 'Date: ')

  var project_id = get(S.state.current_project, 'id', '')
  var params: dict<any> = {
    'content': content,
    'project_id': project_id,
  }
  if !empty(due_date)
    params.due_string = due_date
  endif

  var parent_id = get(next_item, 'parent_id', v:null)
  if type(parent_id) == v:t_string && !empty(parent_id)
    params.parent_id = parent_id
  endif

  Redraw(true)

  api.AddTask(params, (ok: bool, new_task: any) => {
    if !ok
      SetError(['Failed to create task'])
      S.state.is_loading = false
      render.Full()
      return
    endif

    # Insert at position and reorder
    if next_index >= 0 && next_index <= len(S.state.items)
      insert(S.state.items, new_task, next_index)
    else
      add(S.state.items, new_task)
    endif

    var reorder_items: list<dict<any>> = []
    var i = 0
    for item in S.state.items
      add(reorder_items, {'id': item.id, 'child_order': i})
      i += 1
    endfor

    api.ReorderTasks(reorder_items, (ok2: bool, _: any) => {
      ClearError()
      Refresh()
    })
  })
enddef

export def OnComplete()
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  var item = S.state.items[index]
  var item_id = item.id

  var is_checked = get(item, 'checked', false)
  if !is_checked
    is_checked = get(item, 'is_completed', false)
  endif

  item.loading = true
  render.Line(index)

  var OnDone = (ok: bool, result: any) => {
    item.loading = false
    if !ok
      item.error = true
      SetError(['Failed to toggle task completion'])
    else
      item.error = false
      # Toggle checked state (support both field names)
      if has_key(item, 'checked')
        item.checked = !is_checked
      endif
      if has_key(item, 'is_completed')
        item.is_completed = !is_checked
      endif
      ClearError()
    endif
    render.Line(index)
  }

  if is_checked
    api.ReopenTask(item_id, OnDone)
  else
    api.CloseTask(item_id, OnDone)
  endif
enddef

export def OnDelete()
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  var item = S.state.items[index]
  var item_id = item.id

  item.loading = true
  render.Line(index)

  api.DeleteTask(item_id, (ok: bool, result: any) => {
    item.loading = false
    if !ok
      item.error = true
      SetError(['Failed to delete task'])
      render.Line(index)
    else
      ClearError()
      Refresh()
    endif
  })
enddef

export def OnIndent()
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  var current_item = S.state.items[index]

  # Find the previous item at same or lower depth to become parent
  var prev_index = index - 1
  while prev_index > 0 && S.state.items[prev_index].depth > current_item.depth
    prev_index -= 1
  endwhile
  if prev_index < 0
    return
  endif
  var prev_item = S.state.items[prev_index]

  current_item.loading = true
  render.Line(index)

  api.MoveTask(current_item.id, prev_item.id, '', (ok: bool, result: any) => {
    current_item.loading = false
    if !ok
      SetError(['Failed to indent task'])
      render.Line(index)
    else
      ClearError()
      Refresh()
    endif
  })
enddef

export def OnUnindent()
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  var current_item = S.state.items[index]

  var parent_id = get(current_item, 'parent_id', v:null)
  if type(parent_id) != v:t_string || empty(parent_id)
    return
  endif

  # Find the parent item
  var parent_item: dict<any> = {}
  for item in S.state.items
    if item.id == parent_id
      parent_item = item
      break
    endif
  endfor

  if empty(parent_item)
    return
  endif

  var grandparent_id = get(parent_item, 'parent_id', v:null)
  var project_id = ''

  current_item.loading = true
  render.Line(index)

  if type(grandparent_id) == v:t_string && !empty(grandparent_id)
    api.MoveTask(current_item.id, grandparent_id, '', (ok: bool, result: any) => {
      current_item.loading = false
      if !ok
        SetError(['Failed to unindent task'])
        render.Line(index)
      else
        ClearError()
        Refresh()
      endif
    })
  else
    project_id = get(parent_item, 'project_id', get(S.state.current_project, 'id', ''))
    api.MoveTask(current_item.id, '', project_id, (ok: bool, result: any) => {
      current_item.loading = false
      if !ok
        SetError(['Failed to unindent task'])
        render.Line(index)
      else
        ClearError()
        Refresh()
      endif
    })
  endif
enddef

export def OnChangeContent()
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  var item = S.state.items[index]
  var item_id = item.id

  var content = InputPrompt('Question', 'Content: ', get(item, 'content', ''))
  if empty(content) || content == get(item, 'content', '')
    return
  endif

  item.loading = true
  render.Line(index)

  api.UpdateTask(item_id, {'content': content}, (ok: bool, result: any) => {
    item.loading = false
    if !ok
      SetError(['Failed to update task content'])
    else
      ClearError()
    endif
    Refresh()
  })
enddef

export def OnChangeDate()
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  var item = S.state.items[index]
  var item_id = item.id

  var date_str = InputPrompt('Question', 'Date: ')
  if empty(date_str)
    return
  endif

  item.loading = true
  render.Line(index)

  api.UpdateTask(item_id, {'due_string': date_str}, (ok: bool, result: any) => {
    item.loading = false
    if !ok
      SetError(['Failed to update task date'])
    else
      ClearError()
    endif
    Refresh()
  })
enddef

export def OnChangePriority(priority: number)
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  var item = S.state.items[index]
  var item_id = item.id

  if get(item, 'priority', 1) == priority
    return
  endif

  item.loading = true
  render.Line(index)

  api.UpdateTask(item_id, {'priority': priority}, (ok: bool, result: any) => {
    item.loading = false
    if !ok
      SetError(['Failed to update task priority'])
    else
      ClearError()
    endif
    Refresh()
  })
enddef

export def OnProjectArchive()
  SetError(['Project archiving requires the Sync API (premium feature)'])
  render.Full()
enddef

export def OnProjectDelete()
  var project_id = get(S.state.current_project, 'id', '')
  if empty(project_id)
    return
  endif

  Redraw(true)

  api.DeleteProject(project_id, (ok: bool, result: any) => {
    if !ok
      SetError(['Failed to delete project'])
      S.state.is_loading = false
      render.Full()
    else
      ClearError()
      Open(S.state.options.defaultProject)
    endif
  })
enddef

export def OnProjectChangeColor()
  redraw
  for color_number in range(30, 49)
    if color_number == 40
      echomsg ''
    endif
    execute 'echohl todoistColor' .. color_number
    echon ' ' .. color_number .. ' '
    echohl Normal
    echon "\t"
  endfor

  echohl Question
  var color_str = input('Color: ')
  echohl Normal

  var color = str2nr(color_str)
  if color < 30 || color > 49
    return
  endif

  var project_id = get(S.state.current_project, 'id', '')
  if empty(project_id)
    return
  endif

  Redraw(true)

  api.UpdateProject(project_id, {'color': color}, (ok: bool, result: any) => {
    if !ok
      SetError(['Failed to change project color'])
    else
      ClearError()
    endif
    Refresh()
  })
enddef

export def OnProjectChangeName()
  var name = InputPrompt('Question', 'New name: ')
  if empty(name)
    return
  endif

  var project_id = get(S.state.current_project, 'id', '')
  if empty(project_id)
    return
  endif

  Redraw(true)

  api.UpdateProject(project_id, {'name': name}, (ok: bool, result: any) => {
    if !ok
      SetError(['Failed to rename project'])
    else
      S.state.current_project_name = name
      ClearError()
    endif
    Refresh()
  })
enddef

export def OnShowCommentHistory()
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  comments.ShowCommentHistory(S.state.items[index])
enddef

export def OnAddComment()
  var index = GetCurrentItemIndex()
  if index < 0 || index >= len(S.state.items)
    return
  endif
  var item = S.state.items[index]
  comments.AddComment(item.id, get(item, 'content', ''))
enddef

export def ListProjects(): list<string>
  var names: list<string> = []
  for p in S.state.projects
    add(names, get(p, 'name', ''))
  endfor
  return names
enddef

def EnsureProjects()
  if !empty(S.state.projects)
    return
  endif
  var key = GetApiKey()
  if empty(key)
    return
  endif
  var url = 'https://api.todoist.com/api/v1/projects'
  var raw = system('curl -sS ' .. shellescape(url)
    .. ' -H ' .. shellescape('Authorization: Bearer ' .. key))
  if v:shell_error != 0
    return
  endif
  try
    var data = json_decode(raw)
    if type(data) == v:t_dict && has_key(data, 'results')
      S.state.projects = data.results
    endif
  catch
  endtry
enddef

export def CompleteProjects(start: string, line: string, pos: number): list<string>
  EnsureProjects()
  var names: list<string> = []
  for p in S.state.projects
    var name = get(p, 'name', '')
    if name =~? '^' .. escape(start, '~.*[]\\')
      add(names, name)
    endif
  endfor
  return names
enddef
