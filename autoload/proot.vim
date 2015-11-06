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
  " Don't inherit base if they told us not to!
  if g:project_root_implicit_base == 0
    let g:project_root_pt[a:project_type].inherits = []
  else
    let g:project_root_pt[a:project_type].inherits = ['base_project']
  endif
  call extend(g:project_root_pt[a:project_type], additional_options)
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
  let curr_parents = g:project_root_pt[a:project_name]['inherits']
  if get(a:000, 0) == 0
    call s:NubExtend(curr_parents, a:parents)
  else
    call s:NubExtend(curr_parents, a:parents, 0)
  endif
endfunction

" }}}

" The same as Vim's 'extend' function, but will not add duplicate
" elements.
function! s:NubExtend(xs, ys, ...)
  let to_extend = []
  for elt in a:ys
    if index(a:xs, elt) == -1 && index(to_extend, elt) == -1
      call add(to_extend, elt)
    endif
  endfor
  call call('extend', [a:xs, to_extend] + a:000)
endfunction

" }}}

" }}}

" }}}
