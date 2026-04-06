vim9script

# Public autoload bridge for todoist.vim
# Imported by plugin/todoist.vim via `import autoload`

import './todoist/main.vim' as main

export def Open(project_name: string = '')
  main.Open(project_name)
enddef

export def CompleteProjects(ArgLead: string, CmdLine: string, CursorPos: number): list<string>
  return main.CompleteProjects(ArgLead, CmdLine, CursorPos)
enddef

export def ListProjects(): list<string>
  return main.ListProjects()
enddef
