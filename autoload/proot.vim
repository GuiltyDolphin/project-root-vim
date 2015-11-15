" File: project-root.vim
" Author: Ben Moon
" Description: Easier project navigation.
" Last Modified: October 29, 2015
" LICENSE: GNU General Public License version 3 (or later)

" Before {{{

if !exists("g:loaded_project_root")
  runtime plugin/project-root.vim
endif
" if exists("g:loaded_project_root") || &cp
"   finish
" endif
" let g:loaded_project_root = 1

" }}}

" Private {{{

" Project {{{

" Setup {{{

" Project type {{{

" Initialize a project type.
"
" a:project_type should be the name of the project type to initialize.
"
" Optional arguments:
" a:1 should be a dictionary with additional options to extend the project
" type's default settings with.
function! s:InitializeProjectType(project_type, ...)
  if has_key(g:project_root_pt, a:project_type)
    " Don't want to overwrite any user settings.
    return
  endif
  let additional_options = get(a:000, 0, {})

  let g:project_root_pt[a:project_type] = {}
  call extend(g:project_root_pt[a:project_type], additional_options)
  " Inherit base unless the user says otherwise.
  if g:project_root_implicit_base != 0
    call s:ExtendDefault(a:project_type, 'inherits', ['base_project'])
  endif
endfunction

function! proot#initialize_project(project_name, ...)
  call call('s:InitializeProjectType', [a:project_name] + a:000)
endfunction

" Add a:parents to the inheritance tree for a:project_name.
"
" Arguments:
" a:project_name - name of the project type to update.
" a:parents - parents to add.
"
" Optional arguments:
" a:1 (default 0) - When nonzero, the new parents will have a
" higher precedence than the current parents, otherwise they
" will have a lower precedence.
function! proot#project_add_inherits(project_name, parents, ...)
  call call('s:ExtendDefault', [a:project_name, 'inherits', a:parents, []] + a:000)
endfunction

" Allows specifying a function that will run when the project type
" has been set.
"
" Arguments:
" a:project_type - name of project to update.
" a:runners - list of functions to add to the runners.
"
" Optional arguments:
" a:1 (default 0) - When nonzero, the new parents will have a
" higher precedence than the current parents, otherwise they
" will have a lower precedence.
function! proot#add_project_runners(project_type, runners, ...)
  call call('s:ExtendDefault', [a:project_type, 'runners', a:runners, []] + a:000)
endfunction

" }}}

" Lists {{{
"
" The same as Vim's 'extend' function, but will not add duplicate
" elements.
function! s:NubExtend(xs, ys, ...)
  let to_extend = []
  for Elt in a:ys
    if index(a:xs, Elt) == -1 && index(to_extend, Elt) == -1
      call add(to_extend, Elt)
    endif
  endfor
  call call('extend', [a:xs, to_extend] + a:000)
endfunction

" Extend a project list attribute.
"
" Arguments:
" a:project_type - name of project to act upon
" a:attr - name of attribute
" a:ys - list to extend
" Optional arguments:
" a:1 - default value for list if it does not exist (defaults to [])
" a:2 - position at which to extend the list (see Vim's extend() function)
function! s:ExtendDefault(project_type, attr, ys, ...)
  let pdict = g:project_root_pt[a:project_type]
  let default = get(a:000, 0, [])
  if !exists('pdict[a:attr]')
    let pdict[a:attr] = default
  endif
  if a:0 > 1
    call call('s:NubExtend', [pdict[a:attr], a:ys] + a:000[1:])
  else
    call call('s:NubExtend', [pdict[a:attr], a:ys])
  endif
endfunction

" }}}

" }}}

" }}}

" }}}
