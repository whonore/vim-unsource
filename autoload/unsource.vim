let g:unsource_cmds = get(g:, 'unsource_cmds', {})

"""""""""""""
"  Helpers  "
"""""""""""""

function! s:re_prefix(prefix, suffix) abort
  let l:suffixes = ['']
  for l:idx in range(strlen(a:suffix))
    let l:suffixes = add(l:suffixes, l:suffixes[-1] . a:suffix[l:idx])
  endfor
  return printf('\<%s\%%(%s\)\>', a:prefix, join(l:suffixes, '\|'))
endfunction

function! s:trim(line) abort
  return substitute(a:line, '^\s*\(.*\)\s*$', '\1', '')
endfunction

function! s:in(xs, x) abort
  return stridx(a:xs, a:x) != -1
endfunction

function! s:matchall(lines, pat, idx) abort
  let l:matches = []
  for l:line in a:lines
    let l:match = matchlist(l:line, a:pat)
    if l:match != [] && l:match[a:idx] !=# ''
      let l:matches = add(l:matches, l:match[a:idx])
    endif
  endfor
  return l:matches
endfunction

"""""""""""""
"  Regexes  "
"""""""""""""

let s:varname_re = '[gbwt]:\i\+'
let s:let_re = printf('^let\s\+\(%s\)\s*=', s:varname_re)

let s:funcname_re = '\u\i*'
let s:funckwd_re = s:re_prefix('fu', 'nction') . '!\?'
let s:function_re = printf('^%s!\?\s\+\(%s\)', s:funckwd_re, s:funcname_re)

let s:optname_re = '\l\+'
let s:set_kwds = ['set', 'setlocal', 'setglobal']
let s:setkwd_re = s:re_prefix('se', 't')
let s:setlkwd_re = s:re_prefix('setl', 'ocal')
let s:setgkwd_re = s:re_prefix('setg', 'lobal')
let s:set_res = map(
  \ [s:setkwd_re, s:setlkwd_re, s:setgkwd_re],
  \ 'printf("^%s\\s\\+\\(%s\\)", v:val, s:optname_re)'
\)

let s:autocmdkwd_re = s:re_prefix('au', 'tocmd')
let s:autocmd_re = printf('^%s\s\+\(\S\+\s*\S\+\)', s:autocmdkwd_re)

let s:mapkwd_re = join([
  \ '\<map\>!\?',
  \ '\<smap\>',
  \ s:re_prefix('[nvxoilc]m', 'ap'),
  \ s:re_prefix('tma', 'p'),
  \ s:re_prefix('no', 'remap') . '!\?',
  \ s:re_prefix('snor', 'emap'),
  \ s:re_prefix('[nvxl]n', 'oremap'),
  \ s:re_prefix('[oict]no', 'remap')
  \], '\|')
let s:map_re = printf('^\(\%%(%s\)\s\+\S\+\)\s\+\S\+', s:mapkwd_re)

""""""""""""""
"  Matchers  "
""""""""""""""

let s:_lets = 'l'
let s:_functions = 'f'
let s:_sets = 's'
let s:_autocmds = 'a'
let s:_maps = 'm'
let s:_all = s:_lets . s:_functions . s:_sets . s:_autocmds . s:_maps

function! s:lets(lines) abort
  let l:matches = s:matchall(a:lines, s:let_re, 1)
  return l:matches != [] ? ['unlet ' . join(l:matches, ' ')] : []
endfunction

function! s:functions(lines) abort
  let l:matches = s:matchall(a:lines, s:function_re, 1)
  return map(l:matches, '"delfunction " . v:val')
endfunction

function! s:sets(lines) abort
  let l:matches = map(copy(s:set_res), 's:matchall(a:lines, v:val, 1)')
  let l:unsets = []
  for l:idx in range(len(l:matches))
    if l:matches[l:idx] != []
      let l:matches[l:idx] = join(map(l:matches[l:idx], 'v:val . "&"'), ' ')
      let l:unsets = add(l:unsets, s:set_kwds[l:idx] . ' ' . l:matches[l:idx])
    endif
  endfor
  return l:unsets
endfunction

function! s:autocmds(lines) abort
  let l:matches = s:matchall(a:lines, s:autocmd_re, 1)
  return map(l:matches, '"autocmd! " . v:val')
endfunction

function! s:maps(lines) abort
  let l:matches = s:matchall(a:lines, s:map_re, 1)
  let l:unmaps = []
  for [l:map, l:lhs] in map(l:matches, 'split(v:val)')
    let l:mode = l:map =~# '^\%(map\|no\)' ? '' : l:map[0]
    let l:unmap = l:mode . 'unmap' . (s:in(l:map, '!') ? '!' : '')
    let l:unmaps = add(l:unmaps, l:unmap . ' ' . l:lhs)
  endfor
  return l:unmaps
endfunction

"""""""""
"  API  "
"""""""""

function! unsource#unsource_lines(...) abort
  if !(a:0 == 1 || a:0 == 2)
    echoerr 'unsource#unsource_lines expects 1 or 2 arguments'
    return
  endif

  let [l:lines, l:opts] = a:0 == 1 ? [a:1, s:_all] : a:000
  let l:lines = map(l:lines, 's:trim(v:val)')

  let l:lets = s:in(l:opts, s:_lets) ? s:lets(l:lines) : []
  let l:functions = s:in(l:opts, s:_functions) ? s:functions(l:lines) : []
  let l:sets = s:in(l:opts, s:_sets) ? s:sets(l:lines) : []
  let l:autocmds = s:in(l:opts, s:_autocmds) ? s:autocmds(l:lines) : []
  let l:maps = s:in(l:opts, s:_maps) ? s:maps(l:lines) : []

  return l:lets + l:functions + l:sets + l:autocmds + l:maps
endfunction

function! unsource#unsource(...) abort
  if a:0 == 0
    echoerr 'unsource#unsource expects 1 or 2 arguments'
    return
  endif

  let [l:files, l:opts] = a:0 == 1 ? [a:1, s:_all] : a:000[0:1]
  let l:files = type(l:files) != type([]) ? [l:files] : l:files
  let l:dry_run = a:0 == 3 ? a:3 : 0
  let l:lines = []
  let l:undos = []

  for l:file in l:files
    let l:file = expand(l:file)
    if filereadable(l:file)
      let l:lines = readfile(l:file)
      let l:undo = unsource#unsource_lines(l:lines, l:opts)
      if l:undo != []
        let l:undos += l:undo
        let g:unsource_cmds[l:file] = l:undo
      endif
    endif
  endfor

  if !l:dry_run
    for l:undo in l:undos
      execute l:undo
    endfor
  endif
  return l:undos
endfunction
