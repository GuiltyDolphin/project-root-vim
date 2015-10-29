" File: project-root.vim
" Author: Ben Moon
" Description: Easier project navigation.
" Last Modified: October 29, 2015
" LICENSE: GPLv3
" project-root-vim : easier project navigation.
" Copyright © 2015 GuiltyDolphin (Ben Moon)
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.


" Before {{{

if exists("g:loaded_project_root") || &cp
  finish
endif
let g:loaded_project_root = 1

" }}}

" Private {{{

" Project {{{

" Glob {{{

" Project file globs
"
" To add (or overwrite) a project glob use the form
" let g:project_root_pt_{project_type}_globs = [list of globs]
let g:project_root_pt_unknown_globs = ['.git', 'LICEN{S,C}E', 'README*']

" Get the glob pattern to match for the current project type.
function s:GetProjectGlob()
  return s:ListToGlob(extend(
        \ copy(g:project_root_pt_{b:project_root_type}_globs),
        \ g:project_root_pt_unknown_globs))
endfunction

" }}}

" Setup {{{

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
  let current_directory = expand("%:p:h")
  let res = s:GlobUpDir(s:GetProjectGlob(), current_directory)
  if res =~ '\v^$'
    let res = current_directory  " Or whatever default?
  endif
  return res
endfunction

" Set the project type for the current buffer if it hasn't already
" been set.
function! s:SetProjectType()
  if exists('b:project_root_type')
    return
  endif
  let b:project_root_type = s:GetProjectType()
  if !exists('g:project_root_pt_{b:project_root_type}_globs')
    let g:project_root_pt_{b:project_root_type}_globs = g:project_root_pt_unknown_globs
  endif
endfunction

" Determine the current project type.
function! s:GetProjectType()
  if &filetype =~ '\v^$'
    return 'unknown'
  endif
  return &filetype
endfunction

" Initialize project root.
function! s:ProjectRootInitialize()
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
function! s:ListToGlob(to_glob, ...)
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

" }}}

" }}}

" Initialize {{{
augroup ProjectRootInit
  au!
  au BufRead * call <SID>ProjectRootInitialize()
augroup END
" }}}
