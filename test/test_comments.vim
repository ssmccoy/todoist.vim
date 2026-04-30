vim9script

import autoload 'todoist/api.vim' as api
import autoload 'todoist/comments.vim' as comments

# --- Mock infrastructure (same as test_api.vim) ---

var last_cmd: list<string> = []

def MockRunJob(response: string, exit_code: number = 0, http_code: number = 200): func
  return (cmd: list<string>, OnStdout: func(list<string>), OnExit: func(number)): job => {
    last_cmd = cmd
    timer_start(0, (_) => {
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

def CmdUrl(): string
  var x_idx = index(last_cmd, '-X')
  return x_idx >= 0 && x_idx + 2 < len(last_cmd) ? last_cmd[x_idx + 2] : ''
enddef

def CmdMethod(): string
  var x_idx = index(last_cmd, '-X')
  return x_idx >= 0 && x_idx + 1 < len(last_cmd) ? last_cmd[x_idx + 1] : ''
enddef

# --- GetComments ---

def g:Test_Api_GetComments()
  api.Setup('test-key')
  var mock_data = '{"results": [{"id": "c1", "task_id": "42", "content": "First comment", "posted_at": "2024-01-15T14:30:00Z"}, {"id": "c2", "task_id": "42", "content": "Second comment", "posted_at": "2024-01-16T09:15:00Z"}]}'
  g:Todoist_test_run_job = MockRunJob(mock_data)

  var done = false
  var result_ok = false
  var result_data: any = null

  api.GetComments('42', (ok: bool, data: any) => {
    result_ok = ok
    result_data = data
    done = true
  })

  WaitFor(() => done, 'GetComments callback not called')
  assert_true(result_ok)
  assert_equal(2, len(result_data))
  assert_equal('First comment', result_data[0].content)
  assert_equal('Second comment', result_data[1].content)

  assert_equal('GET', CmdMethod())
  assert_true(CmdUrl() =~ '/comments?task_id=42', 'Expected /comments?task_id=42, got: ' .. CmdUrl())
  unlet g:Todoist_test_run_job
enddef

def g:Test_Api_GetComments_empty()
  api.Setup('test-key')
  g:Todoist_test_run_job = MockRunJob('{"results": []}')

  var done = false
  var result_ok = false
  var result_data: any = null

  api.GetComments('99', (ok: bool, data: any) => {
    result_ok = ok
    result_data = data
    done = true
  })

  WaitFor(() => done, 'GetComments empty callback not called')
  assert_true(result_ok)
  assert_equal([], result_data)
  unlet g:Todoist_test_run_job
enddef

# --- AddComment ---

def g:Test_Api_AddComment()
  api.Setup('test-key')
  var mock_data = '{"id": "c99", "task_id": "42", "content": "New comment"}'
  g:Todoist_test_run_job = MockRunJob(mock_data)

  var done = false
  var result_ok = false

  api.AddComment('42', 'New comment', (ok: bool, data: any) => {
    result_ok = ok
    done = true
  })

  WaitFor(() => done, 'AddComment callback not called')
  assert_true(result_ok)
  assert_equal('POST', CmdMethod())
  assert_true(CmdUrl() =~ '/comments$', 'Expected /comments endpoint, got: ' .. CmdUrl())

  var d_idx = index(last_cmd, '-d')
  assert_true(d_idx >= 0, 'Expected -d flag for request body')
  unlet g:Todoist_test_run_job
enddef

# --- FormatDate ---

def g:Test_FormatDate()
  assert_equal('2024-01-15 14:30', comments.FormatDate('2024-01-15T14:30:00Z'))
  assert_equal('2024-01-15 14:30', comments.FormatDate('2024-01-15T14:30:45Z'))
  assert_equal('2024-01-15 09:05', comments.FormatDate('2024-01-15T09:05:00.000000Z'))
  assert_equal('2024-01-15', comments.FormatDate('2024-01-15'))
enddef
