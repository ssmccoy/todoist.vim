vim9script

# Comment viewing and management for todoist.vim
# Handles history buffer and comment creation

import './api.vim' as api

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
    result = ''
  endtry
  echohl Normal
  return result
enddef

export def FormatDate(iso: string): string
  var t_idx = stridx(iso, 'T')
  if t_idx < 0
    return iso
  endif
  var date_part = iso[0 : t_idx - 1]
  var time_rest = iso[t_idx + 1 :]
  var colon1 = stridx(time_rest, ':')
  if colon1 < 0
    return date_part
  endif
  var colon2 = stridx(time_rest, ':', colon1 + 1)
  var time_part = colon2 >= 0 ? time_rest[0 : colon2 - 1] : time_rest
  return date_part .. ' ' .. time_part
enddef

def FormatHistoryLines(task_content: string, comments: list<any>): list<string>
  var lines: list<string> = ['# Comments: ' .. task_content]

  for comment in comments
    var posted = get(comment, 'posted_at', '')
    var date_str = empty(posted) ? '' : FormatDate(posted)
    add(lines, '')
    add(lines, '--- ' .. date_str .. ' ---')
    var content = get(comment, 'content', '')
    if !empty(content)
      lines += split(content, "\n")
    endif
  endfor

  return lines
enddef

# --- Full comment history (scratch buffer) ---

export def ShowCommentHistory(item: dict<any>)
  var task_id = get(item, 'id', '')
  var task_content = get(item, 'content', '')
  if empty(task_id)
    echomsg 'Todoist: Save the task first'
    return
  endif

  var bufname = 'Todoist:comments:' .. task_id
  var existing = bufnr(bufname)
  if existing != -1
    var winid = bufwinid(existing)
    if winid != -1
      win_gotoid(winid)
    else
      execute 'sbuffer ' .. existing
    endif
  else
    belowright new
    execute 'file ' .. bufname
    setlocal filetype=todoist-comments
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal nomodifiable

    b:todoist_task_id = task_id
    b:todoist_task_content = task_content

    nnoremap <buffer><silent> q  <Cmd>bwipe!<CR>
    nnoremap <buffer><silent> C  <ScriptCmd>OnHistoryRefresh()<CR>
    nnoremap <buffer><silent> ca <ScriptCmd>OnHistoryAddComment()<CR>
  endif

  var bufnr = bufnr('%')

  setbufvar(bufnr, '&modifiable', 1)
  setline(1, ['# Comments: ' .. task_content, '', 'Loading...'])
  setbufvar(bufnr, '&modifiable', 0)

  api.GetComments(task_id, (ok: bool, data: any) => {
    if !bufexists(bufnr)
      return
    endif
    var lines: list<string>
    if !ok
      lines = ['# Comments: ' .. task_content, '', 'Failed to fetch comments.']
    else
      lines = FormatHistoryLines(task_content, data)
    endif
    setbufvar(bufnr, '&modifiable', 1)
    deletebufline(bufnr, 1, '$')
    setbufline(bufnr, 1, lines)
    setbufvar(bufnr, '&modifiable', 0)
  })
enddef

def OnHistoryRefresh()
  var task_id = b:todoist_task_id
  var task_content = b:todoist_task_content
  ShowCommentHistory({'id': task_id, 'content': task_content})
enddef

def OnHistoryAddComment()
  var task_id = b:todoist_task_id
  var task_content = b:todoist_task_content
  AddComment(task_id, task_content)
enddef

# --- Add comment ---

export def AddComment(task_id: string, task_content: string)
  if empty(task_id)
    echomsg 'Todoist: Save the task first'
    return
  endif

  var content = InputPrompt('Question', 'Comment: ')
  if empty(content)
    return
  endif

  api.AddComment(task_id, content, (ok: bool, result: any) => {
    if !ok
      echoerr 'Todoist: Failed to add comment'
      return
    endif
    echomsg 'Todoist: Comment added'

    var bufname = 'Todoist:comments:' .. task_id
    var comment_bufnr = bufnr(bufname)
    if comment_bufnr != -1
      ShowCommentHistory({'id': task_id, 'content': task_content})
    endif
  })
enddef
