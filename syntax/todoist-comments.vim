if exists('b:current_syntax')
  finish
endif

syn match todoistCommentTitle /^# Comments: .*/
syn match todoistCommentSep /^--- .* ---$/

hi def link todoistCommentTitle todoistTitle
hi def link todoistCommentSep   Delimiter

let b:current_syntax = 'todoist-comments'
