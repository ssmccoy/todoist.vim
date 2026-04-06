vim9script

# Render engine for todoist.vim
# Port of src/render.js — produces buffer lines with highlight parts

import './colors.vim' as colors
import './compat.vim' as compat
import './dates.vim' as dates
import './state.vim' as S

# Each line is a list of {hl: string, text: string} parts
var header_lines: list<list<dict<string>>> = []
var item_lines: list<list<dict<string>>> = []

const HL_BY_PRIORITY: dict<string> = {
  '4': 'todoistPri1',
  '3': 'todoistPri2',
  '2': 'todoistPri3',
}
const HL_CHECKBOX_DEFAULT = 'todoistCheckbox'

export def Full()
  header_lines = RenderHeader()
  item_lines = []

  for item in S.state.items
    add(item_lines, RenderItem(item))
  endfor

  var all_lines = header_lines + item_lines
  ApplyToBuffer(all_lines)
enddef

export def Line(index: number)
  if index < 0 || index >= len(S.state.items)
    return
  endif
  var parts = RenderItem(S.state.items[index])
  if index < len(item_lines)
    item_lines[index] = parts
  endif
  var line_nr = index + len(header_lines)
  ApplyLineToBuffer(parts, line_nr)
enddef

export def LineToItemIndex(line_number: number): number
  var index = line_number - len(header_lines)
  if index < 0
    return 0
  endif
  if index > (len(item_lines) - 1)
    return len(item_lines) - 1
  endif
  return index
enddef

# --- Apply to buffer ---

def ApplyToBuffer(lines: list<list<dict<string>>>)
  var bufnr = S.state.buffer_id
  if bufnr < 0
    return
  endif

  var ns = compat.GetNamespace()
  var saved_pos = getpos('.')

  # Build text lines
  var text_lines: list<string> = []
  for parts in lines
    var line_text = ''
    for part in parts
      line_text ..= part.text
    endfor
    add(text_lines, line_text)
  endfor

  # Set all lines at once
  setbufvar(bufnr, '&modifiable', 1)
  compat.BufSetLines(bufnr, 0, -1, text_lines)
  setbufvar(bufnr, '&modifiable', 0)

  # Clear all highlights then re-apply
  compat.ClearHighlights(bufnr, ns, 0, -1)

  var lnum = 0
  for parts in lines
    var col = 0
    for part in parts
      var text_len = len(part.text)
      if text_len > 0 && part.hl != '' && part.hl != 'Normal'
        compat.AddHighlight(bufnr, ns, part.hl, lnum, col, col + text_len)
      endif
      col += text_len
    endfor
    lnum += 1
  endfor

  setpos('.', saved_pos)
enddef

def ApplyLineToBuffer(parts: list<dict<string>>, line_nr: number)
  var bufnr = S.state.buffer_id
  if bufnr < 0
    return
  endif

  var ns = compat.GetNamespace()
  var saved_pos = getpos('.')

  # Build line text
  var line_text = ''
  for part in parts
    line_text ..= part.text
  endfor

  # Set single line
  setbufvar(bufnr, '&modifiable', 1)
  compat.BufSetLines(bufnr, line_nr, line_nr + 1, [line_text])
  setbufvar(bufnr, '&modifiable', 0)

  # Clear and re-apply highlights for this line
  compat.ClearHighlights(bufnr, ns, line_nr, line_nr + 1)

  var col = 0
  for part in parts
    var text_len = len(part.text)
    if text_len > 0 && part.hl != '' && part.hl != 'Normal'
      compat.AddHighlight(bufnr, ns, part.hl, line_nr, col, col + text_len)
    endif
    col += text_len
  endfor

  setpos('.', saved_pos)
enddef

# --- Rendering functions ---

def RenderHeader(): list<list<dict<string>>>
  var project_name = S.state.current_project_name
  var project = S.state.current_project
  var project_color = get(project, 'color', '')

  var title_hl = 'todoistTitle'
  if !empty(project_color)
    title_hl = colors.ColorToHighlight(project_color)
    # Special case: Inbox with default color (grey/48)
    if title_hl == 'todoistColor48' && project_name == 'Inbox'
      title_hl = 'todoistTitle'
    endif
  endif

  var title: list<dict<string>> = [{
    'hl': title_hl,
    'text': ' ' .. project_name .. ' (' .. string(len(S.state.items)) .. ' tasks) ',
  }]

  var lines: list<list<dict<string>>> = [title]

  # Error messages
  if !empty(S.state.error_message)
    for msg in S.state.error_message
      add(lines, [{'hl': 'todoistErrorMessage', 'text': msg}])
    endfor
  endif

  # Loading message
  if S.state.is_loading
    add(lines, [{'hl': 'todoistMessage', 'text': 'Loading...'}])
  endif

  # Empty message
  if len(S.state.items) == 0 && !S.state.is_loading
    add(lines, [{'hl': 'todoistMessage', 'text': 'No items'}])
  endif

  # Ensure at least 2 header lines
  if len(lines) < 2
    add(lines, [])
  endif

  return lines
enddef

def RenderItem(item: dict<any>): list<dict<string>>
  return [
    RenderIndent(item),
    RenderCheckbox(item),
    RenderContent(item),
    {'hl': 'todoistSeparator', 'text': ' '},
    RenderDueDate(get(item, 'due', v:null)),
  ]
enddef

def RenderIndent(item: dict<any>): dict<string>
  var depth = get(item, 'depth', 0)
  var icon_width = len(S.state.options.icons.checked) - 1
  return {'hl': 'Normal', 'text': repeat(' ', depth * icon_width)}
enddef

def RenderCheckbox(item: dict<any>): dict<string>
  var icons = S.state.options.icons
  var is_error = get(item, 'error', false)
  var is_loading = get(item, 'loading', false)
  var is_checked = get(item, 'checked', false)
  # REST API v2 uses 'is_completed' instead of 'checked'
  if !is_checked
    is_checked = get(item, 'is_completed', false)
  endif

  var hl: string
  if is_error
    hl = 'todoistError'
  else
    var pri = string(get(item, 'priority', 1))
    hl = get(HL_BY_PRIORITY, pri, HL_CHECKBOX_DEFAULT)
  endif

  var text: string
  if is_loading
    text = icons.loading
  elseif is_error
    text = icons.error
  elseif is_checked
    text = icons.checked
  else
    text = icons.unchecked
  endif

  return {'hl': hl, 'text': text}
enddef

def RenderContent(item: dict<any>): dict<string>
  var is_checked = get(item, 'checked', false)
  if !is_checked
    is_checked = get(item, 'is_completed', false)
  endif
  var hl = 'todoistContent' .. (is_checked ? 'Completed' : '')
  return {'hl': hl, 'text': get(item, 'content', '')}
enddef

def RenderDueDate(due: any): dict<string>
  if type(due) != v:t_dict || empty(due)
    return {'hl': 'todoistDate', 'text': ''}
  endif

  var date_str = get(due, 'date', '')
  if empty(date_str)
    return {'hl': 'todoistDate', 'text': ''}
  endif

  var parts = dates.ParseDate(date_str)
  var hl: string

  if dates.IsOverdue(parts)
    hl = 'todoistDateOverdue'
  elseif dates.IsToday(parts)
    hl = 'todoistDateToday'
  elseif dates.IsTomorrow(parts)
    hl = 'todoistDateTomorrow'
  elseif dates.IsThisWeek(parts)
    hl = 'todoistDateThisWeek'
  else
    hl = 'todoistDate'
  endif

  return {'hl': hl, 'text': '(' .. date_str .. ')'}
enddef
