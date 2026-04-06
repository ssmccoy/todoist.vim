vim9script

import autoload 'todoist/api.vim' as api

# --- Mock infrastructure ---

var last_cmd: list<string> = []

def MockRunJob(response: string, exit_code: number = 0, http_code: number = 200): func
  return (cmd: list<string>, OnStdout: func(list<string>), OnExit: func(number)): job => {
    last_cmd = cmd
    timer_start(0, (_) => {
      # Simulate curl -w '\n%{http_code}' output: each line arrives separately
      if !empty(response)
        OnStdout([response])
      endif
      OnStdout([''])
      OnStdout([string(http_code)])
      timer_start(0, (_) => {
        OnExit(exit_code)
      })
    })
    return test_null_job()
  }
enddef

def WaitFor(Condition: func(): bool, msg: string = 'timed out')
  var timeout = 200
  while !Condition() && timeout > 0
    sleep 10m
    timeout -= 1
  endwhile
  assert_true(Condition(), msg)
enddef

# Get the URL from curl command: ['curl', '-sS', '-X', METHOD, URL, ...]
def CmdUrl(): string
  var x_idx = index(last_cmd, '-X')
  return x_idx >= 0 && x_idx + 2 < len(last_cmd) ? last_cmd[x_idx + 2] : ''
enddef

def CmdMethod(): string
  var x_idx = index(last_cmd, '-X')
  return x_idx >= 0 && x_idx + 1 < len(last_cmd) ? last_cmd[x_idx + 1] : ''
enddef

# --- Setup ---

def g:Test_Api_Setup()
  api.Setup('test-api-key-123')
  # Verify by making a request and checking the command
  g:Todoist_test_run_job = MockRunJob('{"results": []}')
  var done = false
  api.GetProjects((ok: bool, data: any) => {
    done = true
  })
  WaitFor(() => done)
  # Check authorization header contains our key
  var auth_idx = index(last_cmd, 'Authorization: Bearer test-api-key-123')
  assert_true(auth_idx >= 0, 'API key not found in request headers')
  unlet g:Todoist_test_run_job
enddef

# --- GetProjects ---

def g:Test_Api_GetProjects()
  api.Setup('test-key')
  var mock_data = '{"results": [{"id": "1", "name": "Inbox"}, {"id": "2", "name": "Work"}]}'
  g:Todoist_test_run_job = MockRunJob(mock_data)

  var done = false
  var result_ok = false
  var result_data: any = null

  api.GetProjects((ok: bool, data: any) => {
    result_ok = ok
    result_data = data
    done = true
  })

  WaitFor(() => done, 'GetProjects callback not called')
  assert_true(result_ok)
  assert_equal(2, len(result_data))
  assert_equal('Inbox', result_data[0].name)

  # Verify it was a GET to /projects
  assert_equal('GET', CmdMethod())
  assert_true(CmdUrl() =~ '/projects$', 'Expected /projects endpoint, got: ' .. CmdUrl())
  unlet g:Todoist_test_run_job
enddef

# --- GetTasks ---

def g:Test_Api_GetTasks()
  api.Setup('test-key')
  var mock_data = '{"results": [{"id": "10", "content": "Buy milk", "project_id": "1"}]}'
  g:Todoist_test_run_job = MockRunJob(mock_data)

  var done = false
  var result_data: any = null

  api.GetTasks('1', (ok: bool, data: any) => {
    result_data = data
    done = true
  })

  WaitFor(() => done, 'GetTasks callback not called')
  assert_equal(1, len(result_data))
  assert_equal('Buy milk', result_data[0].content)
  assert_true(CmdUrl() =~ 'project_id=1', 'Expected project_id query param, got: ' .. CmdUrl())
  unlet g:Todoist_test_run_job
enddef

# --- AddTask ---

def g:Test_Api_AddTask()
  api.Setup('test-key')
  var mock_data = '{"id": "99", "content": "New task"}'
  g:Todoist_test_run_job = MockRunJob(mock_data)

  var done = false
  var result_ok = false

  api.AddTask({'content': 'New task', 'project_id': '1'}, (ok: bool, data: any) => {
    result_ok = ok
    done = true
  })

  WaitFor(() => done, 'AddTask callback not called')
  assert_true(result_ok)
  assert_equal('POST', CmdMethod())
  # Check body was passed via -d flag
  var d_idx = index(last_cmd, '-d')
  assert_true(d_idx >= 0, 'Expected -d flag for request body')
  unlet g:Todoist_test_run_job
enddef

# --- DeleteTask ---

def g:Test_Api_DeleteTask()
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('')

  var done = false
  var result_ok = false

  api.DeleteTask('42', (ok: bool, data: any) => {
    result_ok = ok
    done = true
  })

  WaitFor(() => done, 'DeleteTask callback not called')
  assert_true(result_ok)
  assert_equal('DELETE', CmdMethod())
  assert_true(CmdUrl() =~ '/tasks/42$', 'Expected /tasks/42 endpoint, got: ' .. CmdUrl())
  unlet g:Todoist_test_run_job
enddef

# --- CloseTask ---

def g:Test_Api_CloseTask()
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('')

  var done = false

  api.CloseTask('42', (ok: bool, data: any) => {
    done = true
  })

  WaitFor(() => done, 'CloseTask callback not called')
  assert_equal('POST', CmdMethod())
  assert_true(CmdUrl() =~ '/tasks/42/close$', 'Expected /tasks/42/close endpoint, got: ' .. CmdUrl())
  unlet g:Todoist_test_run_job
enddef

# --- ReopenTask ---

def g:Test_Api_ReopenTask()
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('')

  var done = false

  api.ReopenTask('42', (ok: bool, data: any) => {
    done = true
  })

  WaitFor(() => done, 'ReopenTask callback not called')
  assert_true(CmdUrl() =~ '/tasks/42/reopen$', 'Expected /tasks/42/reopen endpoint, got: ' .. CmdUrl())
  unlet g:Todoist_test_run_job
enddef

# --- Error handling ---

def g:Test_Api_request_failure()
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('curl error', 1)

  var done = false
  var result_ok = true

  api.GetProjects((ok: bool, data: any) => {
    result_ok = ok
    done = true
  })

  WaitFor(() => done, 'failure callback not called')
  assert_false(result_ok)
  unlet g:Todoist_test_run_job
enddef

def g:Test_Api_empty_response()
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('')

  var done = false
  var result_ok = false
  var result_data: any = null

  api.DeleteTask('1', (ok: bool, data: any) => {
    result_ok = ok
    result_data = data
    done = true
  })

  WaitFor(() => done, 'empty response callback not called')
  assert_true(result_ok)
  assert_equal({}, result_data)
  unlet g:Todoist_test_run_job
enddef

def g:Test_Api_invalid_json()
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('not valid json {{{')

  var done = false
  var result_ok = true

  # Use a non-paginated endpoint to test raw JSON parsing
  api.AddTask({'content': 'test'}, (ok: bool, data: any) => {
    result_ok = ok
    done = true
  })

  WaitFor(() => done, 'invalid json callback not called')
  assert_false(result_ok)
  unlet g:Todoist_test_run_job
enddef

def g:Test_Api_error_response_detected()
  # API returns valid JSON but no "results" key (e.g. {"error": "Forbidden"})
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('{"error": "Forbidden"}', 0, 200)

  var done = false
  var result_ok = true

  api.GetProjects((ok: bool, data: any) => {
    result_ok = ok
    done = true
  })

  WaitFor(() => done, 'error response callback not called')
  assert_false(result_ok)
  unlet g:Todoist_test_run_job
enddef

def g:Test_Api_http_error()
  # API returns 403 Forbidden — should be detected as failure
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('{"error": "Forbidden"}', 0, 403)

  var done = false
  var result_ok = true

  api.GetProjects((ok: bool, data: any) => {
    result_ok = ok
    done = true
  })

  WaitFor(() => done, 'http error callback not called')
  assert_false(result_ok)
  unlet g:Todoist_test_run_job
enddef

# --- URL construction ---

def g:Test_Api_base_url()
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('{"results": []}')

  var done = false
  api.GetProjects((ok: bool, data: any) => {
    done = true
  })

  WaitFor(() => done)
  assert_true(CmdUrl() =~ '^https://api.todoist.com/api/v1/', 'Expected v1 API base URL, got: ' .. CmdUrl())
  unlet g:Todoist_test_run_job
enddef
