vim9script

import autoload 'todoist/models.vim' as models

# --- ProcessItems ---

def g:Test_ProcessItems_empty()
  assert_equal([], models.ProcessItems([]))
enddef

def g:Test_ProcessItems_flat_sorted()
  var items = [
    {'id': '3', 'content': 'C', 'child_order': 3},
    {'id': '1', 'content': 'A', 'child_order': 1},
    {'id': '2', 'content': 'B', 'child_order': 2},
  ]
  var result = models.ProcessItems(items)
  assert_equal(3, len(result))
  assert_equal('A', result[0].content)
  assert_equal('B', result[1].content)
  assert_equal('C', result[2].content)
  assert_equal(0, result[0].depth)
  assert_equal(0, result[1].depth)
  assert_equal(0, result[2].depth)
enddef

def g:Test_ProcessItems_parent_child()
  var items = [
    {'id': '1', 'content': 'Parent', 'child_order': 1},
    {'id': '2', 'content': 'Child1', 'child_order': 1, 'parent_id': '1'},
    {'id': '3', 'content': 'Child2', 'child_order': 2, 'parent_id': '1'},
  ]
  var result = models.ProcessItems(items)
  assert_equal(3, len(result))
  assert_equal('Parent', result[0].content)
  assert_equal(0, result[0].depth)
  assert_equal('Child1', result[1].content)
  assert_equal(1, result[1].depth)
  assert_equal('Child2', result[2].content)
  assert_equal(1, result[2].depth)
enddef

def g:Test_ProcessItems_nested_3_levels()
  var items = [
    {'id': '1', 'content': 'Root', 'child_order': 1},
    {'id': '2', 'content': 'Mid', 'child_order': 1, 'parent_id': '1'},
    {'id': '3', 'content': 'Leaf', 'child_order': 1, 'parent_id': '2'},
  ]
  var result = models.ProcessItems(items)
  assert_equal(3, len(result))
  assert_equal(0, result[0].depth)
  assert_equal(1, result[1].depth)
  assert_equal(2, result[2].depth)
enddef

def g:Test_ProcessItems_orphan()
  # Child points to non-existent parent — treated as root
  var items = [
    {'id': '1', 'content': 'Normal', 'child_order': 2},
    {'id': '2', 'content': 'Orphan', 'child_order': 1, 'parent_id': '999'},
  ]
  var result = models.ProcessItems(items)
  assert_equal(2, len(result))
  assert_equal(0, result[0].depth)
  assert_equal(0, result[1].depth)
enddef

def g:Test_ProcessItems_sort_children()
  var items = [
    {'id': '1', 'content': 'Parent', 'child_order': 1},
    {'id': '3', 'content': 'Second', 'child_order': 2, 'parent_id': '1'},
    {'id': '2', 'content': 'First', 'child_order': 1, 'parent_id': '1'},
  ]
  var result = models.ProcessItems(items)
  assert_equal('First', result[1].content)
  assert_equal('Second', result[2].content)
enddef

# --- CompareByOrder ---

def g:Test_CompareByOrder_basic()
  assert_true(models.CompareByOrder({'child_order': 1}, {'child_order': 2}) < 0)
  assert_true(models.CompareByOrder({'child_order': 2}, {'child_order': 1}) > 0)
  assert_equal(0, models.CompareByOrder({'child_order': 1}, {'child_order': 1}))
enddef

def g:Test_CompareByOrder_fallback_to_order()
  assert_true(models.CompareByOrder({'order': 1}, {'order': 2}) < 0)
enddef

def g:Test_CompareByOrder_missing_both()
  assert_equal(0, models.CompareByOrder({}, {}))
enddef
