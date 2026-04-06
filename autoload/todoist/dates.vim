vim9script

# Date utilities for todoist.vim
# Replaces date-fns: parseISO, isToday, isTomorrow, isOverdue, isThisWeek

# Parse "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SS" into [year, month, day, hour, min, sec]
export def ParseDate(input: string): list<number>
  if len(input) < 10
    return []
  endif
  var year = str2nr(input[0 : 3])
  var month = str2nr(input[5 : 6])
  var day = str2nr(input[8 : 9])
  var hour = 23
  var min = 59
  var sec = 59
  if len(input) >= 19
    hour = str2nr(input[11 : 12])
    min = str2nr(input[14 : 15])
    sec = str2nr(input[17 : 18])
  endif
  return [year, month, day, hour, min, sec]
enddef

def Now(): list<number>
  var t = localtime()
  return [
    str2nr(strftime('%Y', t)),
    str2nr(strftime('%m', t)),
    str2nr(strftime('%d', t)),
    str2nr(strftime('%H', t)),
    str2nr(strftime('%M', t)),
    str2nr(strftime('%S', t)),
  ]
enddef

def Today(): list<number>
  var n = Now()
  return [n[0], n[1], n[2]]
enddef

# Compare two date lists: -1 if a < b, 0 if equal, 1 if a > b
def CompareDates(a: list<number>, b: list<number>): number
  var len_a = len(a)
  var len_b = len(b)
  var max_len = len_a > len_b ? len_a : len_b
  var i = 0
  while i < max_len
    var va = i < len_a ? a[i] : 0
    var vb = i < len_b ? b[i] : 0
    if va < vb
      return -1
    elseif va > vb
      return 1
    endif
    i += 1
  endwhile
  return 0
enddef

# Add N days to a [year, month, day] date
def AddDays(date: list<number>, days: number): list<number>
  var y = date[0]
  var m = date[1]
  var d = date[2] + days

  while true
    var dim = DaysInMonth(y, m)
    if d <= dim
      break
    endif
    d -= dim
    m += 1
    if m > 12
      m = 1
      y += 1
    endif
  endwhile

  return [y, m, d]
enddef

def DaysInMonth(year: number, month: number): number
  var days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
  if month == 2 && IsLeapYear(year)
    return 29
  endif
  return days[month]
enddef

def IsLeapYear(year: number): bool
  return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
enddef

export def IsOverdue(parts: list<number>): bool
  if empty(parts)
    return false
  endif
  var now = Now()
  return CompareDates(parts, now) < 0
enddef

export def IsToday(parts: list<number>): bool
  if empty(parts)
    return false
  endif
  var today = Today()
  return parts[0] == today[0] && parts[1] == today[1] && parts[2] == today[2]
enddef

export def IsTomorrow(parts: list<number>): bool
  if empty(parts)
    return false
  endif
  var tomorrow = AddDays(Today(), 1)
  return parts[0] == tomorrow[0] && parts[1] == tomorrow[1] && parts[2] == tomorrow[2]
enddef

export def IsThisWeek(parts: list<number>): bool
  if empty(parts)
    return false
  endif
  var today = Today()
  var week_end = AddDays(today, 7)
  # Within next 7 days (exclusive of today/tomorrow which have their own highlights)
  return CompareDates([parts[0], parts[1], parts[2]], today) > 0
    && CompareDates([parts[0], parts[1], parts[2]], week_end) <= 0
enddef

export def FormatDate(parts: list<number>): string
  if empty(parts)
    return ''
  endif
  return printf('%04d-%02d-%02d', parts[0], parts[1], parts[2])
enddef
