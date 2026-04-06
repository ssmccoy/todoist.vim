vim9script

# Todoist API client for todoist.vim
# Uses API v1 for REST operations, Sync API v1 for reorder/move

import './compat.vim' as compat

var api_key: string = ''
const BASE_URL = 'https://api.todoist.com/api/v1'
const SYNC_URL = BASE_URL .. '/sync'

export def Setup(key: string)
  api_key = key
enddef

# --- Core HTTP ---

# Callback: (ok: bool, data: any) => void
export def Request(method: string, endpoint: string, body: dict<any>, Callback: func(bool, any))
  var url = BASE_URL .. endpoint
  var cmd = ['curl', '-sS', '-w', '\n%{http_code}', '-X', method, url,
    '-H', 'Authorization: Bearer ' .. api_key,
    '-H', 'Content-Type: application/json']
  if !empty(body)
    cmd += ['-d', json_encode(body)]
  endif
  DoRequest(cmd, Callback)
enddef

def SyncRequest(commands: list<dict<any>>, Callback: func(bool, any))
  var cmd = ['curl', '-sS', '-w', '\n%{http_code}', '-X', 'POST', SYNC_URL,
    '-H', 'Authorization: Bearer ' .. api_key,
    '--data-urlencode', 'commands=' .. json_encode(commands)]
  DoRequest(cmd, Callback)
enddef

# Paginated GET: collects all pages of "results" into a single list
def PaginatedGet(endpoint: string, Callback: func(bool, any), collected: list<any> = [])
  var url = endpoint
  Request('GET', url, {}, (ok: bool, data: any) => {
    if !ok
      Callback(false, data)
      return
    endif
    if type(data) != v:t_dict || !has_key(data, 'results')
      Callback(false, data)
      return
    endif
    var results = data.results
    var all = collected + results
    var next_cursor = get(data, 'next_cursor', v:null)
    if next_cursor != v:null && !empty(next_cursor)
      # Append or update cursor param
      var sep = stridx(endpoint, '?') >= 0 ? '&' : '?'
      PaginatedGet(endpoint .. sep .. 'cursor=' .. next_cursor, Callback, all)
    else
      Callback(true, all)
    endif
  })
enddef

def DoRequest(cmd: list<string>, Callback: func(bool, any))
  var chunks: list<string> = []

  compat.RunJob(cmd,
    (data: list<string>) => {
      chunks += data
    },
    (exit_code: number) => {
      var raw = join(chunks, "\n")

      if exit_code != 0
        timer_start(0, (_) => {
          Callback(false, raw)
        })
        return
      endif

      # Extract HTTP status code from last line (added by -w '\n%{http_code}')
      var lines = split(raw, '\n')
      var http_code = 0
      if len(lines) > 0
        http_code = str2nr(lines[-1])
        remove(lines, -1)
      endif
      var response = join(lines, "\n")

      if http_code >= 400
        timer_start(0, (_) => {
          Callback(false, 'HTTP ' .. http_code .. ': ' .. response)
        })
        return
      endif

      if empty(response)
        # Some endpoints (DELETE, close, reopen) return empty 204
        timer_start(0, (_) => {
          Callback(true, {})
        })
        return
      endif

      try
        var parsed = json_decode(response)
        timer_start(0, (_) => {
          Callback(true, parsed)
        })
      catch
        timer_start(0, (_) => {
          Callback(false, response)
        })
      endtry
    })
enddef

# --- Project operations ---

export def GetProjects(Callback: func(bool, any))
  PaginatedGet('/projects', Callback)
enddef

export def AddProject(params: dict<any>, Callback: func(bool, any))
  Request('POST', '/projects', params, Callback)
enddef

export def UpdateProject(id: string, params: dict<any>, Callback: func(bool, any))
  Request('POST', '/projects/' .. id, params, Callback)
enddef

export def DeleteProject(id: string, Callback: func(bool, any))
  Request('DELETE', '/projects/' .. id, {}, Callback)
enddef

# --- Task operations ---

export def GetTasks(project_id: string, Callback: func(bool, any))
  PaginatedGet('/tasks?project_id=' .. project_id, Callback)
enddef

export def AddTask(params: dict<any>, Callback: func(bool, any))
  Request('POST', '/tasks', params, Callback)
enddef

export def UpdateTask(id: string, params: dict<any>, Callback: func(bool, any))
  Request('POST', '/tasks/' .. id, params, Callback)
enddef

export def CloseTask(id: string, Callback: func(bool, any))
  Request('POST', '/tasks/' .. id .. '/close', {}, Callback)
enddef

export def ReopenTask(id: string, Callback: func(bool, any))
  Request('POST', '/tasks/' .. id .. '/reopen', {}, Callback)
enddef

export def DeleteTask(id: string, Callback: func(bool, any))
  Request('DELETE', '/tasks/' .. id, {}, Callback)
enddef

# --- Sync API operations (for reorder/move) ---

export def MoveTask(id: string, parent_id: any, project_id: string, Callback: func(bool, any))
  var args: dict<any> = {'id': id}
  if type(parent_id) == v:t_string && !empty(parent_id)
    args.parent_id = parent_id
  elseif !empty(project_id)
    args.project_id = project_id
  endif
  var commands = [{
    'type': 'item_move',
    'uuid': GenerateUUID(),
    'args': args,
  }]
  SyncRequest(commands, Callback)
enddef

export def ReorderTasks(items_order: list<dict<any>>, Callback: func(bool, any))
  var commands = [{
    'type': 'item_reorder',
    'uuid': GenerateUUID(),
    'args': {'items': items_order},
  }]
  SyncRequest(commands, Callback)
enddef

# Simple UUID generator (good enough for API idempotency)
var uuid_counter: number = 0
def GenerateUUID(): string
  uuid_counter += 1
  return printf('%s-%d-%d', strftime('%Y%m%d%H%M%S'), getpid(), uuid_counter)
enddef
