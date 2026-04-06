vim9script

import autoload 'todoist/detail.vim' as detail
import autoload 'todoist/state.vim' as S

# --- Priority mapping ---

def g:Test_PriorityFromApi()
  assert_equal('p1', detail.PriorityFromApi(4))
  assert_equal('p2', detail.PriorityFromApi(3))
  assert_equal('p3', detail.PriorityFromApi(2))
  assert_equal('p4', detail.PriorityFromApi(1))
  assert_equal('p4', detail.PriorityFromApi(0))
enddef

def g:Test_PriorityToApi()
  assert_equal(4, detail.PriorityToApi('p1'))
  assert_equal(3, detail.PriorityToApi('p2'))
  assert_equal(2, detail.PriorityToApi('p3'))
  assert_equal(1, detail.PriorityToApi('p4'))
  assert_equal(1, detail.PriorityToApi('invalid'))
enddef

def g:Test_Priority_roundtrip()
  for n in [1, 2, 3, 4]
    assert_equal(n, detail.PriorityToApi(detail.PriorityFromApi(n)))
  endfor
enddef

# --- Project resolution ---

def SetupProjects()
  S.state.projects = [
    {'id': 'p1', 'name': 'Inbox'},
    {'id': 'p2', 'name': 'Work'},
    {'id': 'p3', 'name': 'Personal'},
  ]
  S.state.current_project = {'id': 'p1', 'name': 'Inbox'}
  S.state.current_project_name = 'Inbox'
enddef

def g:Test_ResolveProjectName()
  SetupProjects()
  assert_equal('Inbox', detail.ResolveProjectName('p1'))
  assert_equal('Work', detail.ResolveProjectName('p2'))
  # Unknown ID falls back to current project name
  assert_equal('Inbox', detail.ResolveProjectName('unknown'))
enddef

def g:Test_ResolveProjectId()
  SetupProjects()
  assert_equal('p1', detail.ResolveProjectId('Inbox'))
  assert_equal('p2', detail.ResolveProjectId('Work'))
  # Unknown name falls back to current project id
  assert_equal('p1', detail.ResolveProjectId('Nonexistent'))
enddef

# --- FormatTask ---

def g:Test_FormatTask_full()
  SetupProjects()
  S.state.items = []
  var item = {
    'id': '10',
    'content': 'Buy groceries',
    'description': "Get the following:\n- Milk\n- Eggs",
    'project_id': 'p1',
    'priority': 4,
    'due': {'date': '2024-01-15', 'string': 'tomorrow'},
    'labels': ['shopping', 'urgent'],
    'parent_id': v:null,
  }
  var lines = detail.FormatTask(item)
  assert_equal('# Buy groceries', lines[0])
  assert_equal('Project: Inbox | Pri: p1 | Due: tomorrow', lines[1])
  assert_equal('Labels: shopping, urgent', lines[2])
  assert_equal('', lines[3])
  assert_equal('Get the following:', lines[4])
  assert_equal('- Milk', lines[5])
  assert_equal('- Eggs', lines[6])
enddef

def g:Test_FormatTask_minimal()
  SetupProjects()
  S.state.items = []
  var item = {
    'id': '11',
    'content': 'Simple task',
    'description': '',
    'project_id': 'p2',
    'priority': 1,
    'labels': [],
    'parent_id': v:null,
  }
  var lines = detail.FormatTask(item)
  assert_equal('# Simple task', lines[0])
  assert_equal('Project: Work | Pri: p4 | Due: ', lines[1])
  # No Labels line (empty), no Parent line
  assert_equal('', lines[2])
  assert_equal(3, len(lines))
enddef

def g:Test_FormatTask_with_parent()
  SetupProjects()
  S.state.items = [
    {'id': '20', 'content': 'Parent task'},
    {'id': '21', 'content': 'Child task', 'parent_id': '20'},
  ]
  var item = S.state.items[1]
  extend(item, {'description': '', 'project_id': 'p1', 'priority': 1,
    'labels': [], 'due': v:null})
  var lines = detail.FormatTask(item)
  assert_equal('Parent: Parent task', lines[2])
enddef

# --- FormatNewTask ---

def g:Test_FormatNewTask()
  SetupProjects()
  var lines = detail.FormatNewTask()
  assert_equal('# ', lines[0])
  assert_true(lines[1] =~ '^Project: Inbox | Pri: p4 | Due: $')
  assert_equal('', lines[2])
  assert_equal(3, len(lines))
enddef

# --- ParseBuffer ---

def g:Test_ParseBuffer_full()
  SetupProjects()
  var lines = [
    '# Buy groceries',
    'Project: Inbox | Pri: p1 | Due: tomorrow',
    'Labels: shopping, urgent',
    '',
    'Get the following:',
    '- Milk',
    '- Eggs',
  ]
  var params = detail.ParseBuffer(lines)
  assert_equal('Buy groceries', params.content)
  assert_equal('p1', params.project_id)
  assert_equal(4, params.priority)
  assert_equal('tomorrow', params.due_string)
  assert_equal(['shopping', 'urgent'], params.labels)
  assert_equal("Get the following:\n- Milk\n- Eggs", params.description)
enddef

def g:Test_ParseBuffer_minimal()
  SetupProjects()
  var lines = [
    '# Simple task',
    'Project: Work | Pri: p4 | Due: ',
    '',
  ]
  var params = detail.ParseBuffer(lines)
  assert_equal('Simple task', params.content)
  assert_equal('p2', params.project_id)
  assert_equal(1, params.priority)
  assert_false(has_key(params, 'due_string'))
  assert_equal('', params.description)
enddef

def g:Test_ParseBuffer_no_description()
  SetupProjects()
  var lines = [
    '# Task title',
    'Project: Inbox | Pri: p3 | Due: next Monday',
    '',
  ]
  var params = detail.ParseBuffer(lines)
  assert_equal('Task title', params.content)
  assert_equal(2, params.priority)
  assert_equal('next Monday', params.due_string)
  assert_equal('', params.description)
enddef

def g:Test_ParseBuffer_roundtrip()
  SetupProjects()
  S.state.items = []
  var item = {
    'id': '99',
    'content': 'Roundtrip test',
    'description': "Line 1\nLine 2\nLine 3",
    'project_id': 'p2',
    'priority': 3,
    'due': {'date': '2024-06-01', 'string': 'Jun 1'},
    'labels': ['alpha', 'beta'],
    'parent_id': v:null,
  }
  var lines = detail.FormatTask(item)
  var params = detail.ParseBuffer(lines)
  assert_equal('Roundtrip test', params.content)
  assert_equal('p2', params.project_id)
  assert_equal(3, params.priority)
  assert_equal('Jun 1', params.due_string)
  assert_equal(['alpha', 'beta'], params.labels)
  assert_equal("Line 1\nLine 2\nLine 3", params.description)
enddef

def g:Test_ParseBuffer_empty()
  var params = detail.ParseBuffer([])
  assert_equal({}, params)
enddef
