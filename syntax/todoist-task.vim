if exists('b:current_syntax')
  finish
endif

" Title line (line 1 only)
syn match todoistTaskTitleMarker /\%1l# / contained
syn match todoistTaskTitle /\%1l# .*/ contains=todoistTaskTitleMarker

" Dense metadata line (line 2): Project: ... | Pri: ... | Due: ...
syn match todoistTaskMetaSep /|/ contained
syn match todoistTaskKeyName /\(Project\|Pri\|Due\|Labels\|Parent\):/ contained
syn match todoistTaskMeta /^\(Project\|Pri\|Due\):.*/ contains=todoistTaskKeyName,todoistTaskMetaSep,todoistTaskPri1,todoistTaskPri2,todoistTaskPri3

" Optional field lines
syn match todoistTaskOptional /^\(Labels\|Parent\): .*/ contains=todoistTaskKeyName

" Priority highlighting within metadata
syn match todoistTaskPri1 /Pri: p1/ contained
syn match todoistTaskPri2 /Pri: p2/ contained
syn match todoistTaskPri3 /Pri: p3/ contained

" Description region: everything after the first blank line inherits markdown
syn include @Markdown syntax/markdown.vim
syn region todoistTaskDescription start=/\(^$\n\)\@<=./ end=/\%$/ contains=@Markdown

let b:current_syntax = 'todoist-task'
