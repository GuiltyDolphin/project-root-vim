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

" Searching for file patterns {{{

function! s:PreferredSearchMethod(project_type)
  return get(g:project_root_pt[a:project_type], 'prefer_search', g:project_root_search_method)
endfunction

" Optional arguments:
" a:1 - type of file (same as in the 'find' command on Linux)
function! s:ProjectGlobDown(attr, ...)
  let ftype = get(a:000, 0)
  let start_dir = b:project_root_directory
  let res_order = s:GetResolutionOrder(b:project_root_type, a:attr)
  for parent in res_order
    let globs = g:project_root_pt[parent][a:attr]
    if globs == []
      continue
    endif
    let prefer_search = s:PreferredSearchMethod(parent)
    if prefer_search =~ '\cfirst'
      let res = s:ProjectGlobDownFirst(globs, start_dir, ftype)
    elseif prefer_search =~ '\cpriority'
      let res = s:ProjectGlobDownPriority(globs, start_dir, ftype)
    endif
    if res != []
      return res
    endif
  endfor
  return []
endfunction

function! s:ProjectGlobDownFirst(glob_list, start_directory, ...)
  let ftype = get(a:000, 0)
  let glb = s:ListToGlob(a:glob_list)
  return s:FindDown(a:start_directory, glb, ftype)
endfunction

function! s:ProjectGlobDownPriority(glob_list, start_directory, ...)
  let ftype = get(a:000, 0)
  for glb in a:glob_list
    let res = s:FindDown(a:start_directory, glb, ftype)
    if res != []
      return res
    endif
  endfor
  return []
endfunction

" }}}

" Testing {{{

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

" Get the test command for running tests for an individual file.
function! s:TestCommandFile()
  let with_tests = s:GetResolutionOrder(b:project_root_type, 'test_command_file')
  let test_file = s:TestFileName()
  if empty(test_file) || empty(glob(test_file))
    return ''
  endif
  for parent in with_tests
    let pdict = g:project_root_pt[parent]
    let TestCommand = pdict.test_command_file
    let tcommand = call(TestCommand, [test_file])
    if !empty(tcommand)
      return tcommand
    endif
  endfor
  return ''
endfunction

" Get the path to the test file for the current file.
function! s:TestFileName()
  let test_file_gens = s:GetResolutionOrder(
        \ b:project_root_type, 'test_file_gen')
  for parent in test_file_gens
    let pdict = g:project_root_pt[parent]
    let TestGen = pdict.test_file_gen
    let rel_root = s:FileRelativeToRoot()
    let res = call(TestGen, [rel_root])
    if !empty(res)
      return s:SubRoot(res)
    endif
  endfor
  return ''
endfunction

" Get the filepath for the current buffer relative to the project
" root.
function! s:FileRelativeToRoot()
  return substitute(
        \ expand("%:p"), b:project_root_directory, '', '')
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
  let b:project_root_type = s:GetProjectType()
  call proot#initialize_project(b:project_root_type)
endfunction

" Determine the current project type.
function! s:GetProjectType()
  if &filetype =~ '\v^$'
    return 'unknown'
  endif
  return &filetype
endfunction

" }}}

" Initialize project root for the current buffer.
function! s:InitializeBuffer()
  call s:SetProjectType()
  call s:SetProjectRootDirectory()
  return 1
endfunction

function! s:InitializeBufferLate()
  if exists('b:project_root_type')
    return
  endif
  call s:InitializeBuffer()
endfunction

" }}}

" }}}

" Globbing {{{

" Producing Globs {{{

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


" Generate a glob that will ignore casing for alpha characters.
"
" a:pattern should be a string (preferably one that could be used
" as a glob pattern).
"
" Example:
" s:GlobIgnoreCase("foo") would become "[Ff][Oo][Oo]"
function! s:GlobIgnoreCase(pattern)
  return substitute(a:pattern, '\a', '[\u\0\l\0]', 'g')
endfunction

" }}}

" Searching {{{

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

" Find matches for name, searching recursively downwards from
" start_directory.
"
" Returns a list of paths.
function! s:FindDown(start_directory, name, ...)
  let ftype = get(a:000, 0)
  if ftype
    let fstr = ' -type ' . ftype
  else
    let fstr = ''
  endif
  let search_names = join(expand(a:name, 0, 1), "' -o -name '")
  return systemlist(
        \ "find " . a:start_directory
        \ . " -name '" . search_names . "'"
        \ . fstr)
endfunction

" }}}

" }}}

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

" Utility {{{

" Create a path including a:path as a sub-path of the root
" directory.
function! s:SubRoot(path)
  return simplify(b:project_root_directory . '/' . a:path)
endfunction

" }}}

" }}}

" Commands {{{

" Testing {{{

" Attempts to run tests for the current project.
function! s:ProjectRootTest()
  let test_command = s:ProjectTestCommand()
  if empty(test_command)
    echo "No tests found"
  else
    exec '!cd ' . b:project_root_directory . ' && ' . test_command
  endif
endfunction

function! s:ProjectRootTestFile()
  let test_command = s:TestCommandFile()
  if empty(test_command)
    echo "No tests found"
  else
    exec '!cd ' . b:project_root_directory . ' && ' . test_command
  endif
endfunction

function! s:ProjectRootOpenTest()
  let test_file = s:TestFileName()
  if empty(test_file) || empty(glob(test_file))
    echo "Could not find test file"
  else
    exec 'split ' . test_file
  endif
endfunction

" }}}

" Browsing {{{

" Utility {{{

" Open a directory browser for the given directory.
function! s:ProjectRootBrowse(dir)
  if exists(':NERDTreeToggle')
    exec 'NERDTreeToggle ' . a:dir
  elseif exists(':Sexplore')
    exec 'Sexplore ' . a:dir
  else
    echoerr 'Could not open a directory browser'
  endif
endfunction

" Get a subdirectory of the root directory using the glob patterns for a
" project.
function! s:RootSubDir(glob_attr)
  let res = s:ProjectGlobDown(a:glob_attr, 'd')
  if res == []
    return ''
  endif
  return res[0]
endfunction

" }}}

" Open a directory browser for the current project root directory.
function! s:ProjectRootBrowseRoot()
  call s:ProjectRootBrowse(b:project_root_directory)
endfunction

" Tests {{{

function! s:ProjectRootGetTestDir()
  return s:RootSubDir('test_globs')
endfunction

function! s:ProjectRootBrowseTests()
  let test_dir = s:ProjectRootGetTestDir()
  if test_dir =~ '\v^$'
    echo "No test directory found"
    return
  endif
  call s:ProjectRootBrowse(test_dir)
endfunction

" }}}

" Source {{{

function! s:ProjectRootGetSourceDir()
  return s:RootSubDir('source_globs')
endfunction

function! s:ProjectRootBrowseSource()
  let source_dir = s:ProjectRootGetSourceDir()
  if source_dir =~ '\v^$'
    echo "No source directory found"
    return
  endif
  call s:ProjectRootBrowse(source_dir)
endfunction

" }}}

" }}}

" Initialize {{{

function! s:ProjectRootInitCommands()
  command! ProjectRootBrowseRoot :call <SID>ProjectRootBrowseRoot()
  command! ProjectRootTest :call <SID>ProjectRootTest()
  command! ProjectRootBrowseTests :call <SID>ProjectRootBrowseTests()
  command! ProjectRootBrowseSource :call <SID>ProjectRootBrowseSource()
  command! ProjectRootOpenTest :call <SID>ProjectRootOpenTest()
  command! ProjectRootTestFile :call <SID>ProjectRootTestFile()
endfunction

" }}}

" }}}

" Initialize {{{

" Initialize Settings {{{

function! s:InitializeGlobalSettings()
  call s:InitializeGlobalSetting('project_root_search_method', 'priority')
  call s:InitializeGlobalSetting('project_root_implicit_base', 1)
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
  au FileType * call <SID>InitializeBuffer()
  au BufRead,BufNewFile * call <SID>InitializeBufferLate()
augroup END

" }}}
