vim9script

# State management and configuration for todoist.vim

export const DEFAULT_OPTIONS: dict<any> = {
  'key': '',
  'icons': {
    'unchecked': ' [ ] ',
    'checked':   ' [x] ',
    'loading':   ' [...] ',
    'error':     ' [!] ',
  },
  'defaultProject': 'Inbox',
  'useMarkdownSyntax': true,
}

export var state: dict<any> = {
  'options': {},
  'is_loading': true,
  'buffer_id': -1,
  'error_message': [],
  'current_project_name': '',
  'current_project': {},
  'projects': [],
  'items': [],
}

export def Reset()
  state.options = {}
  state.is_loading = true
  state.buffer_id = -1
  state.error_message = []
  state.current_project_name = ''
  state.current_project = {}
  state.projects = []
  state.items = []
enddef

export def LoadOptions()
  var user_opts = get(g:, 'todoist', {})
  state.options = MergeDeep(DEFAULT_OPTIONS, user_opts)
enddef

export def MergeDeep(base: dict<any>, override: dict<any>): dict<any>
  var result = copy(base)
  for [key, val] in items(override)
    if type(val) == v:t_dict && has_key(result, key) && type(result[key]) == v:t_dict
      result[key] = MergeDeep(result[key], val)
    else
      result[key] = val
    endif
  endfor
  return result
enddef
