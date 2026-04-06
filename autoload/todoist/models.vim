vim9script

# Data model processing for todoist.vim
# Port of src/models.js — tree building, sorting, flattening

export def ProcessItems(items: list<dict<any>>): list<dict<any>>
  # Build id -> item index
  var by_id: dict<any> = {}
  for item in items
    var id_str = item.id
    by_id[id_str] = item
    item.children = []
  endfor

  # Build tree
  var root_items: list<dict<any>> = []
  for item in items
    var parent_id = get(item, 'parent_id', v:null)
    if parent_id == v:null || parent_id == ''
      add(root_items, item)
    else
      var parent_id_str = parent_id
      if has_key(by_id, parent_id_str)
        var parent = by_id[parent_id_str]
        add(parent.children, item)
      else
        # Orphaned item — treat as root
        add(root_items, item)
      endif
    endif
  endfor

  # Sort by order
  sort(root_items, CompareByOrder)
  SortChildrenRecursive(root_items)

  # Flatten with depth
  return Flatten(root_items, [], 0)
enddef

def Flatten(items: list<dict<any>>, result: list<dict<any>>, depth: number): list<dict<any>>
  for item in items
    item.depth = depth
    add(result, item)
    Flatten(item.children, result, depth + 1)
  endfor
  return result
enddef

def SortChildrenRecursive(items: list<dict<any>>)
  for item in items
    sort(item.children, CompareByOrder)
    SortChildrenRecursive(item.children)
  endfor
enddef

export def CompareByOrder(a: dict<any>, b: dict<any>): number
  var a_order = get(a, 'child_order', get(a, 'order', 0))
  var b_order = get(b, 'child_order', get(b, 'order', 0))
  return a_order - b_order
enddef
