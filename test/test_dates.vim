vim9script

import autoload 'todoist/dates.vim' as dates

# --- ParseDate ---

def g:Test_ParseDate_date_only()
  var result = dates.ParseDate('2024-01-15')
  assert_equal([2024, 1, 15, 23, 59, 59], result)
enddef

def g:Test_ParseDate_datetime()
  var result = dates.ParseDate('2024-01-15T10:30:00')
  assert_equal([2024, 1, 15, 10, 30, 0], result)
enddef

def g:Test_ParseDate_short_input()
  assert_equal([], dates.ParseDate('2024'))
enddef

def g:Test_ParseDate_empty()
  assert_equal([], dates.ParseDate(''))
enddef

def g:Test_ParseDate_midnight()
  var result = dates.ParseDate('2024-12-31T00:00:00')
  assert_equal([2024, 12, 31, 0, 0, 0], result)
enddef

# --- FormatDate ---

def g:Test_FormatDate_normal()
  assert_equal('2024-01-15', dates.FormatDate([2024, 1, 15]))
enddef

def g:Test_FormatDate_empty()
  assert_equal('', dates.FormatDate([]))
enddef

def g:Test_FormatDate_zero_padding()
  assert_equal('2024-03-05', dates.FormatDate([2024, 3, 5]))
enddef

# --- IsOverdue ---

def g:Test_IsOverdue_empty()
  assert_false(dates.IsOverdue([]))
enddef

def g:Test_IsOverdue_past()
  assert_true(dates.IsOverdue([2020, 1, 1, 0, 0, 0]))
enddef

def g:Test_IsOverdue_far_future()
  assert_false(dates.IsOverdue([2099, 12, 31, 23, 59, 59]))
enddef

# --- IsToday ---

def g:Test_IsToday_empty()
  assert_false(dates.IsToday([]))
enddef

def g:Test_IsToday_today()
  var y = str2nr(strftime('%Y'))
  var m = str2nr(strftime('%m'))
  var d = str2nr(strftime('%d'))
  assert_true(dates.IsToday([y, m, d, 12, 0, 0]))
enddef

def g:Test_IsToday_yesterday()
  # Use a date far in the past — definitely not today
  assert_false(dates.IsToday([2020, 6, 15, 12, 0, 0]))
enddef

# --- IsTomorrow ---

def g:Test_IsTomorrow_empty()
  assert_false(dates.IsTomorrow([]))
enddef

def g:Test_IsTomorrow_tomorrow()
  # Compute tomorrow by adding 86400 seconds
  var t = localtime() + 86400
  var y = str2nr(strftime('%Y', t))
  var m = str2nr(strftime('%m', t))
  var d = str2nr(strftime('%d', t))
  assert_true(dates.IsTomorrow([y, m, d, 12, 0, 0]))
enddef

def g:Test_IsTomorrow_today()
  var y = str2nr(strftime('%Y'))
  var m = str2nr(strftime('%m'))
  var d = str2nr(strftime('%d'))
  assert_false(dates.IsTomorrow([y, m, d, 12, 0, 0]))
enddef

# --- IsThisWeek ---

def g:Test_IsThisWeek_empty()
  assert_false(dates.IsThisWeek([]))
enddef

def g:Test_IsThisWeek_3_days_out()
  var t = localtime() + 3 * 86400
  var y = str2nr(strftime('%Y', t))
  var m = str2nr(strftime('%m', t))
  var d = str2nr(strftime('%d', t))
  assert_true(dates.IsThisWeek([y, m, d, 12, 0, 0]))
enddef

def g:Test_IsThisWeek_far_future()
  assert_false(dates.IsThisWeek([2099, 1, 1, 0, 0, 0]))
enddef

def g:Test_IsThisWeek_today_excluded()
  # IsThisWeek excludes today (today has its own highlight)
  var y = str2nr(strftime('%Y'))
  var m = str2nr(strftime('%m'))
  var d = str2nr(strftime('%d'))
  assert_false(dates.IsThisWeek([y, m, d, 12, 0, 0]))
enddef
