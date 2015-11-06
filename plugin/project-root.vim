" File: project-root.vim
" Author: Ben Moon
" Description: Easier project navigation.
" Last Modified: October 29, 2015
" LICENSE: GNU General Public License version 3 (or later)

" Before {{{

if exists("g:loaded_project_root") || &cp
  finish
endif
let g:loaded_project_root = 1

" }}}

" Private {{{

" Project {{{

" Glob {{{

" Create a flat glob pattern that will match all of the globs for the
" given project type.
function! s:ProjectGlobsToGlob(project_type)
  return s:ListToGlob(g:project_root_pt_{a:project_type}_globs)
endfunction

" Project types {{{

" Initializes the 'base_project' project type along with the project
" dictionary.
function! s:InitializeProjectBase()
  " The base dictionary for project configuration.
  if !exists("g:project_root_pt")
    let g:project_root_pt = {}
  endif
  if !exists("g:project_root_pt.base_project")
    " Base project type for implicit inheritance.
    let g:project_root_pt.base_project =
          \ { 'root_globs': ['.git', s:GlobIgnoreCase('licen{s,c}e'),
          \                  s:GlobIgnoreCase('readme*')],
          \   'test_globs': [s:GlobIgnoreCase('test{s,}')],
          \   'source_globs': [s:GlobIgnoreCase('source'),
          \                    s:GlobIgnoreCase('src')],
          \   'inherits':   [],
          \ }
  endif
endfunction

" }}}

" Testing {{{

function! s:PreferredSearchMethod(project_type)
  return get(g:project_root_pt[a:project_type], 'prefer_search', g:project_root_search_method)
endfunction

" Get the test command for the current project type.
function! s:ProjectTestCommand()
  let with_tests = s:GetResolutionOrder(b:project_root_type, 'test_command')
  for parent in with_tests
    let pdict = g:project_root_pt[parent]
    let test_command = pdict.test_command
    if !empty(test_command)
      return test_command
    endif
  endfor
  return ''
endfunction

" }}}

" Setup {{{

" Project directory {{{

" Set the project root directory if it doesn't already exist for
" the current buffer.
function! s:SetProjectRootDirectory()
  if exists('b:project_root_directory')
    return
  endif
  let b:project_root_directory = s:GetProjectRootDirectory()
endfunction

" Attempt to find the root project directory for a file.
"
" Only really works if there is a standard file (or directory structure)
" that indicates the root of a project - e.g, for Haskell (Cabal)
" projects, there is usually a .cabal file at the root of the project.
"
" If no project directory can be found then the current directory
" is returned instead.
function! s:GetProjectRootDirectory()
  if g:project_root_search_method == 'priority'
    return s:GetProjectRootDirectoryPriority()
  elseif g:project_root_search_method == 'first'
    return s:GetProjectRootDirectoryFirst()
  endif
endfunction

" Get the project root directory without regards to the globs ordering.
"
" All globs defined in the pt_globs variable are searched for
" simultaneously.
"
" Example:
" If g:project_root_pt_foo_globs = ["base", "base_other"]
"
" Then the first parent tree matching the glob "base" or "base_other"
" will be returned.
"
" Will perform at best 1 search, and at worst 2*d searches, where
" d is the depth of the current directory relative to the root
" directory ('/').
function! s:GetProjectRootDirectoryFirst(...)
  let current_directory = expand("%:p:h")
  let project_type = get(a:000, 0, b:project_root_type)
  let res_order = s:GetResolutionOrder(project_type, 'root_globs')
  for parent in res_order
    let curr_dict = g:project_root_pt[parent]
    let curr_globs = s:ListToGlob(curr_dict.root_globs)
    if curr_globs =~ '\v^$'
      continue
    endif
    let res = s:GlobUpDir(curr_globs, current_directory)
    if res !~ '\v^$'
      return res
    endif
  endfor
  return current_directory
endfunction

" Get the project root directory based on the globs ordering.
"
" This gives priority to items defined earlier in the pt_globs
" variables.
"
" Example:
" If g:project_root_pt_foo_globs = ["base", "base_other"]
"
" Then first the parent tree will be searched with the glob 'base',
" then will return the first directory containing 'base' if found,
" otherwise will search for 'base_other'.
"
" This will perform 1 search in the best case, or n*d + u*d searches
" in the worst case, where n is the number of globs in the pt_globs
" variable, u is the number of globs in the pt_unknown_globs variable,
" and d is the depth of the current directory relative to the root
" directory ('/').
"
" Optional arguments:
" a:1 - The project type for which the globs should be used.
"       Defaults to the current project type.
function! s:GetProjectRootDirectoryPriority(...)
  let current_directory = expand("%:p:h")
  let project_type = get(a:000, 0, b:project_root_type)
  let res_order = s:GetResolutionOrder(project_type, 'root_globs')
  for parent in res_order
    let globs = g:project_root_pt[parent].root_globs
    for glb in globs
      let res = s:GlobUpDir(glb, current_directory)
      if res !~ '\v^$'
        return res
      endif
    endfor
  endfor
  return current_directory
endfunction

" }}}

" Project type {{{

" Set the project type for the current buffer if it hasn't already
" been set.
function! s:SetProjectType()
  if exists('b:project_root_type')
    return
  endif
  let b:project_root_type = s:GetProjectType()
  call proot#initialize_project(b:project_root_type)
endfunction

" Determine the current project type.
function! s:GetProjectType()
  if &filetype =~ '\v^$'
    return 'unknown'
  endif
  return s:NormalizeProjectType(&filetype)
endfunction

" Normalize a project type
function! s:NormalizeProjectType(project_type)
  return substitute(a:project_type, '\v(^\d|[^0-9a-zA-Z_])', '_', 'g')
endfunction

" }}}

" Initialize project root.
function! s:InitializeBuffer()
  call s:SetProjectType()
  call s:SetProjectRootDirectory()
  return 1
endfunction


" }}}

" }}}

" Globbing {{{

" Generate a glob pattern that will match any of the items in the
" given list.
"
" Basically, for a list ['a', 'b', 'c'], it will generate
" the pattern "{a,b,c}".
"
" Optional arguments:
" a:1 - When nonzero will produce a glob that makes the items optional
" (e.g, would produce "{a,b,c,}" for the above example).
"
" Issue: The '' string returned when the initial list is empty will
" match the current directory (no string match required) - it should
" match nothing!
function! s:ListToGlob(to_glob, ...)
  if len(a:to_glob) == 0
    return ''  " Shouldn't match anything!
  endif
  let allow_other = get(a:000, 0) ? ',' : ''
  return '{' . join(a:to_glob, ',') . allow_other . '}'
endfunction

" Starting with the directory of a:start_path, searches upwards
" for a:pattern, returning the first result or an empty string.
"
" Note that 'first result' refers to the first set of matches in a
" single directory - this may contain several individual matches.
function! s:GlobUp(pattern, start_path)
  let curr_dir = fnamemodify(a:start_path, ":p:h")
  while 1
    let curr_res = globpath(curr_dir, a:pattern)
    if curr_res !~ '\v^$'
      return curr_res
    endif
    " When the base-most path has been checked.
    if curr_dir =~ '\v^[./]$'
      return ''
    endif
    let curr_dir = fnamemodify(curr_dir, ":h")
  endwhile
endfunction

" The same as *GlobUp*, but will return the first directory
" containing the match, rather than all the matches.
function! s:GlobUpDir(pattern, start_directory)
  let curr_dir = fnamemodify(a:start_directory, ":p")
  while 1
    let curr_res = globpath(curr_dir, a:pattern)
    if curr_res !~ '\v^$'
      return curr_dir
    endif
    " When the base-most path has been checked.
    if curr_dir =~ '\v^[./]$'
      return ''
    endif
    let curr_dir = fnamemodify(curr_dir, ":h")
  endwhile
endfunction


" Inheritance {{{

" Get the order in which a particular attribute should be resolved for the
" given project dictionary.
function! s:GetResolutionOrder(project_type, attr)
  let inheritance_order = []
  let curr_dict = g:project_root_pt[a:project_type]

  if has_key(curr_dict, a:attr)
    call add(inheritance_order, a:project_type)
  endif

  if get(curr_dict, 'satisfactory', 0) != 0
    return inheritance_order
  endif

  for parent in curr_dict.inherits
    let inherit_dicts = s:GetResolutionOrder(parent, a:attr)
    let without_repeats = filter(copy(inherit_dicts), 'index(inheritance_order, v:val) == -1')
    call extend(inheritance_order, without_repeats)
  endfor
  return inheritance_order
endfunction

" }}}

" }}}

" Commands {{{

" Attempts to run tests for the current project.
function! s:ProjectRootTest()
  let test_command = s:ProjectTestCommand()
  if empty(test_command)
    echo "No tests found"
  else
    exec '!cd ' . b:project_root_directory . ' && ' . test_command
  endif
endfunction


" Open a directory browser for the current project root directory.
function! s:ProjectRootBrowseRoot()
  call s:ProjectRootBrowse(b:project_root_directory)
endfunction

function! s:ProjectRootBrowse(dir)
  if exists(':NERDTreeToggle')
    exec 'NERDTreeToggle ' . a:dir
  elseif exists(':Sexplore')
    exec 'Sexplore ' . a:dir
  else
    echoerr 'Could not open a directory browser'
  endif
endfunction


" Initialize {{{

function! s:ProjectRootInitCommands()
  command! ProjectRootBrowseRoot :call <SID>ProjectRootBrowseRoot()
  command! ProjectRootTest :call <SID>ProjectRootTest()
endfunction

" }}}

" }}}

" Initialize {{{

" Initialize Settings {{{

function! s:InitializeGlobalSettings()
  call s:InitializeGlobalSetting('project_root_search_method', 'priority')
endfunction

function! s:InitializeGlobalSetting(name, default)
  if !exists('g:{a:name}')
    let g:{a:name} = a:default
  endif
endfunction

" }}}

" Initialize globals
function! s:ProjectRootInitGlobal()
  call s:InitializeGlobalSettings()
  call s:InitializeProjectBase()
endfunction

call <SID>ProjectRootInitGlobal()

call <SID>ProjectRootInitCommands()

augroup ProjectRootInit
  au!
  au BufRead,BufNewFile * call <SID>InitializeBuffer()
augroup END

" }}}
