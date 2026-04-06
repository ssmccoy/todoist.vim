vim9script

# Test runner for todoist.nvim
# Discovers and runs g:Test_* functions, reports results via v:errors
# Expects g:test_file, g:test_output_file and &rtp to be set before sourcing

execute 'source ' .. g:test_file

var test_funcs = getcompletion('Test_', 'function')

var total = 0
var passed = 0
var failed = 0
var output_lines: list<string> = []

for Fname in test_funcs
  total += 1
  v:errors = []
  try
    call(Fname, [])
  catch
    add(v:errors, 'uncaught exception: ' .. v:exception .. ' at ' .. v:throwpoint)
  endtry
  if empty(v:errors)
    passed += 1
    add(output_lines, '[PASS] ' .. Fname)
  else
    failed += 1
    for err in v:errors
      add(output_lines, '[FAIL] ' .. Fname .. ': ' .. err)
    endfor
  endif
endfor

add(output_lines, '')
add(output_lines, printf('Results: %d/%d passed', passed, total))

writefile(output_lines, g:test_output_file)

if failed > 0
  cq
else
  qa!
endif
