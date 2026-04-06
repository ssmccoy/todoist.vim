vim9script

import autoload 'todoist/colors.vim' as colors
import autoload 'todoist/render.vim' as render
import autoload 'todoist/state.vim' as S

# Set up highlights that the render code expects (normally done by plugin/todoist.vim + colors.vim)
def SetupTestHighlights()
  for hl in ['todoistTitle', 'todoistDateOverdue', 'todoistDateToday',
      'todoistDateTomorrow', 'todoistDateThisWeek', 'todoistPri1',
      'todoistPri2', 'todoistPri3', 'todoistContent',
      'todoistContentCompleted', 'todoistCheckbox', 'todoistDate',
      'todoistSeparator', 'todoistErrorMessage', 'todoistMessage',
      'todoistError']
    if !hlexists(hl)
      execute 'hi ' .. hl .. ' guifg=NONE'
    endif
  endfor
  colors.SetupHighlights()
enddef

def SetupBuffer(): number
  new
  setlocal buftype=nofile
  return bufnr('%')
enddef

def CleanupBuffer(bufnr: number)
  execute 'bwipe! ' .. bufnr
enddef

# --- Full render with empty state ---

def g:Test_Render_Full_empty()
  SetupTestHighlights()
  S.Reset()
  S.LoadOptions()
  var bufnr = SetupBuffer()
  S.state.buffer_id = bufnr
  S.state.is_loading = false
  S.state.current_project_name = 'TestProject'
  S.state.current_project = {'id': '1', 'name': 'TestProject', 'color': 'blue'}

  render.Full()

  var lines = getbufline(bufnr, 1, '$')
  assert_true(len(lines) >= 2, 'Expected at least 2 header lines')
  assert_true(lines[0] =~ 'TestProject', 'Expected project name in header')
  assert_true(lines[0] =~ '0 tasks', 'Expected 0 tasks count')
  # Should show "No items" message
  var all_text = join(lines, "\n")
  assert_true(all_text =~ 'No items', 'Expected "No items" message')

  CleanupBuffer(bufnr)
enddef

# --- Full render with items ---

def g:Test_Render_Full_with_items()
  SetupTestHighlights()
  S.Reset()
  S.LoadOptions()
  var bufnr = SetupBuffer()
  S.state.buffer_id = bufnr
  S.state.is_loading = false
  S.state.current_project_name = 'Work'
  S.state.current_project = {'id': '2', 'name': 'Work', 'color': 'red'}
  S.state.items = [
    {'id': '10', 'content': 'Buy milk', 'depth': 0, 'priority': 1, 'children': [],
     'is_completed': false},
    {'id': '11', 'content': 'Write code', 'depth': 0, 'priority': 4, 'children': [],
     'is_completed': false, 'due': {'date': '2020-01-01'}},
    {'id': '12', 'content': 'Done task', 'depth': 1, 'priority': 1, 'children': [],
     'is_completed': true},
  ]

  render.Full()

  var lines = getbufline(bufnr, 1, '$')
  assert_true(lines[0] =~ 'Work', 'Expected project name')
  assert_true(lines[0] =~ '3 tasks', 'Expected 3 tasks count')

  # Items should appear after header
  var all_text = join(lines, "\n")
  assert_true(all_text =~ 'Buy milk', 'Expected task content "Buy milk"')
  assert_true(all_text =~ 'Write code', 'Expected task content "Write code"')
  assert_true(all_text =~ 'Done task', 'Expected task content "Done task"')
  assert_true(all_text =~ '2020-01-01', 'Expected due date')

  CleanupBuffer(bufnr)
enddef

# --- Single line re-render ---

def g:Test_Render_Line()
  SetupTestHighlights()
  S.Reset()
  S.LoadOptions()
  var bufnr = SetupBuffer()
  S.state.buffer_id = bufnr
  S.state.is_loading = false
  S.state.current_project_name = 'Test'
  S.state.current_project = {'id': '1', 'name': 'Test', 'color': 'green'}
  S.state.items = [
    {'id': '10', 'content': 'Task A', 'depth': 0, 'priority': 1, 'children': [],
     'is_completed': false},
    {'id': '11', 'content': 'Task B', 'depth': 0, 'priority': 1, 'children': [],
     'is_completed': false},
  ]

  render.Full()

  # Change item and re-render single line
  S.state.items[0].content = 'Task A Updated'
  render.Line(0)

  var lines = getbufline(bufnr, 1, '$')
  var all_text = join(lines, "\n")
  assert_true(all_text =~ 'Task A Updated', 'Expected updated content')
  assert_true(all_text =~ 'Task B', 'Expected unchanged Task B')

  CleanupBuffer(bufnr)
enddef

# --- LineToItemIndex ---

def g:Test_Render_LineToItemIndex()
  SetupTestHighlights()
  S.Reset()
  S.LoadOptions()
  var bufnr = SetupBuffer()
  S.state.buffer_id = bufnr
  S.state.is_loading = false
  S.state.current_project_name = 'Test'
  S.state.current_project = {'id': '1', 'name': 'Test', 'color': 'green'}
  S.state.items = [
    {'id': '10', 'content': 'First', 'depth': 0, 'priority': 1, 'children': [],
     'is_completed': false},
    {'id': '11', 'content': 'Second', 'depth': 0, 'priority': 1, 'children': [],
     'is_completed': false},
  ]

  render.Full()

  # Header is 2 lines (title + empty), so item 0 is at line 2 (0-indexed)
  assert_equal(0, render.LineToItemIndex(2))
  assert_equal(1, render.LineToItemIndex(3))
  # Clamped to valid range
  assert_equal(0, render.LineToItemIndex(0))
  assert_equal(1, render.LineToItemIndex(99))

  CleanupBuffer(bufnr)
enddef

# --- Loading state ---

def g:Test_Render_Full_loading()
  SetupTestHighlights()
  S.Reset()
  S.LoadOptions()
  var bufnr = SetupBuffer()
  S.state.buffer_id = bufnr
  S.state.is_loading = true
  S.state.current_project_name = 'Loading'
  S.state.current_project = {'id': '1', 'name': 'Loading', 'color': 'grey'}

  render.Full()

  var lines = getbufline(bufnr, 1, '$')
  var all_text = join(lines, "\n")
  assert_true(all_text =~ 'Loading\.\.\.', 'Expected loading message')

  CleanupBuffer(bufnr)
enddef

# --- Error state ---

def g:Test_Render_Full_error()
  SetupTestHighlights()
  S.Reset()
  S.LoadOptions()
  var bufnr = SetupBuffer()
  S.state.buffer_id = bufnr
  S.state.is_loading = false
  S.state.current_project_name = 'Test'
  S.state.current_project = {'id': '1', 'name': 'Test', 'color': 'blue'}
  S.state.error_message = ['Something went wrong']

  render.Full()

  var lines = getbufline(bufnr, 1, '$')
  var all_text = join(lines, "\n")
  assert_true(all_text =~ 'Something went wrong', 'Expected error message in output')

  CleanupBuffer(bufnr)
enddef
