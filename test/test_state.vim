vim9script

import autoload 'todoist/state.vim' as S

# --- MergeDeep ---

def g:Test_MergeDeep_empty_override()
  var result = S.MergeDeep({'a': 1}, {})
  assert_equal({'a': 1}, result)
enddef

def g:Test_MergeDeep_simple_override()
  var result = S.MergeDeep({'a': 1}, {'a': 2})
  assert_equal({'a': 2}, result)
enddef

def g:Test_MergeDeep_add_key()
  var result = S.MergeDeep({'a': 1}, {'b': 2})
  assert_equal({'a': 1, 'b': 2}, result)
enddef

def g:Test_MergeDeep_nested()
  var base = {'x': {'a': 1, 'b': 2}}
  var override = {'x': {'b': 3, 'c': 4}}
  var result = S.MergeDeep(base, override)
  assert_equal({'x': {'a': 1, 'b': 3, 'c': 4}}, result)
enddef

def g:Test_MergeDeep_does_not_mutate()
  var base = {'a': 1, 'b': 2}
  var override = {'b': 99}
  S.MergeDeep(base, override)
  assert_equal(2, base.b)
enddef

# --- Reset ---

def g:Test_Reset()
  S.state.buffer_id = 42
  S.state.current_project_name = 'Test'
  S.state.items = [{'id': '1'}]
  S.Reset()
  assert_equal(-1, S.state.buffer_id)
  assert_equal('', S.state.current_project_name)
  assert_equal([], S.state.items)
  assert_true(S.state.is_loading)
enddef

# --- LoadOptions ---

def g:Test_LoadOptions_defaults()
  # Remove g:todoist if set
  if exists('g:todoist')
    unlet g:todoist
  endif
  S.LoadOptions()
  assert_equal('', S.state.options.key)
  assert_equal('Inbox', S.state.options.defaultProject)
  assert_equal(' [ ] ', S.state.options.icons.unchecked)
enddef

def g:Test_LoadOptions_custom_key()
  g:todoist = {'key': 'test-api-key'}
  S.LoadOptions()
  assert_equal('test-api-key', S.state.options.key)
  # Defaults should still be present
  assert_equal('Inbox', S.state.options.defaultProject)
  unlet g:todoist
enddef

def g:Test_LoadOptions_deep_merge_icons()
  g:todoist = {'icons': {'checked': ' [X] '}}
  S.LoadOptions()
  # Overridden icon
  assert_equal(' [X] ', S.state.options.icons.checked)
  # Other icons preserved
  assert_equal(' [ ] ', S.state.options.icons.unchecked)
  assert_equal(' [...] ', S.state.options.icons.loading)
  unlet g:todoist
enddef
