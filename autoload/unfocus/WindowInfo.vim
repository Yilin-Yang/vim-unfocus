""
" Helper object for uniquely identifying a window and setting window values.
"
" Contains a `winid` and helper functions for retrieving a |tabpagenr()|
" and a |bufnr()|. Combined, these can represent the state of a buffer being
" currently open in a particular window.

let s:typename = 'WindowInfo'
let s:prefix = 'unfocus#WindowInfo#'

""
" Construct a new WindowInfo object from a {winid} as returned by a function
" like |win_getid()|."
"
" @throws NotFound if {winid} doesn't correspond to an existing window.
" @throws WrongType if {winid} is not a number.
function! {s:prefix}New(winid) abort
  let l:new = deepcopy(s:PROTOTYPE)
  " note that winbufnr() takes a numeric argument, and accepts a window-ID
  " therefore, a winid must be a number
  let l:new.winid = a:winid
  return l:new
endfunction
let s:PROTOTYPE = typevim#make#Class(
    \ s:typename, {
      \ 'winid': v:null,
      \ 'bufnr': function(s:prefix.'bufnr'),
      \ 'tabnr': function(s:prefix.'tabnr'),
      \ 'getwinvar': function(s:prefix.'getwinvar'),
      \ 'setwinvar': function(s:prefix.'setwinvar'),
      \ 'GetVals': function(s:prefix.'GetVals'),
      \ 'SetVals': function(s:prefix.'SetVals'),
      \ 'Exists': function(s:prefix.'Exists'),
      \ 'Goto': function(s:prefix.'Goto'),
    \ })

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! s:AssertStillExists(self) abort
  if !a:self.Exists()
    throw maktaba#error#NotFound(
        \ printf('Window %d no longer exists', a:self.winid))
  endif
endfunction

""
" Retrieve the |tabpagenr()| in which this window is currently being shown.
"
" @throws NotFound if the window no longer exists, or if a |tabpagenr()| cannot be retrieved.
function! {s:prefix}tabnr() dict abort
  call s:AssertStillExists(l:self)
  let l:tabnr = win_id2tabwin(l:self.winid)[0]
  if l:tabnr ==# 0
    throw maktaba#error#NotFound(
        \ 'tabpage lookup failed for winid %d', l:self.winid)
  endif
  return l:tabnr
endfunction

""
" Retrieve the |bufnr()| in which this window is currently being shown.
"
" @throws NotFound if the window no longer exists, or if a |bufnr()| cannot be retrieved.
function! {s:prefix}bufnr() dict abort
  call s:AssertStillExists(l:self)
  let l:bufnr = winbufnr(l:self.winid)
  if l:bufnr ==# -1
    throw maktaba#error#NotFound(
        \ 'buffer lookup failed for winid %d', l:self.winid)
  endif
  return l:bufnr
endfunction

""
" Retrieve the value of a particular variable (window-local setting,
" window-local variable, etc.) for this window. Returns [default] if no value
" could be retrieved.
"
" @default default=`""`, the empty string.
"
" @throws NotFound if the window no longer exists.
" @throws WrongType if {varname} is not a string.
function! {s:prefix}getwinvar(varname, ...) dict abort
  call s:CheckType(l:self)
  call s:AssertStillExists(l:self)
  call maktaba#ensure#IsString(a:varname)
  let l:default = get(a:000, 0, '')
  return gettabwinvar(l:self.tabnr(), l:self.winid, a:varname, l:default)
endfunction

""
" Set the value of a variable {varname} to {val} in this window.
"
" @throws NotFound if the window no longer exists.
" @throws WrongType if {varname} is not a string.
function! {s:prefix}setwinvar(varname, val) dict abort
  call s:CheckType(l:self)
  call s:AssertStillExists(l:self)
  call maktaba#ensure#IsString(a:varname)
  call settabwinvar(l:self.tabnr(), l:self.winid, a:varname, a:val)
endfunction

""
" Given {for_vars}, return a dict between those variables and
" their current values for the window.
"
" @throws WrongType if {for_vars} is not a list of strings.
function! {s:prefix}GetVals(for_vars) dict abort
  call s:CheckType(l:self)
  call s:AssertStillExists(l:self)
  call maktaba#ensure#IsList(a:for_vars)
  let l:current_vals = {}
  for l:varname in a:for_vars
    call maktaba#ensure#IsString(l:varname)
    let l:current_vals[l:varname] = l:self.getwinvar(l:varname)
  endfor
  return l:current_vals
endfunction

""
" Set the current values of the variables {vars_and_vals} in this Window and
" return the old values of those variables.
"
" Strong guarantee: if an exception is thrown while setting variable values,
" all variables that had been updated until that point will be restored to
" their prior values.
"
" @throws WrongType if {vars_and_vals} is not a dict.
function! {s:prefix}SetVals(vars_and_vals) dict abort
  call s:CheckType(l:self)
  call s:AssertStillExists(l:self)
  call maktaba#ensure#IsDict(a:vars_and_vals)
  let l:old_vals = {}
  try
    for [l:var, l:val] in items(a:vars_and_vals)
      let l:old_vals[l:var] = l:self.getwinvar(l:var)
      call l:self.setwinvar(l:var, l:val)
    endfor
  catch
    for [l:var, l:val] in items(l:old_vals)
      call l:self.setwinvar(l:var, l:val)
    endfor
    throw typevim#Rethrow()
  endtry
  return l:old_vals
endfunction

""
" Return true if the managed window still exists and false otherwise.
function! {s:prefix}Exists() dict abort
  call s:CheckType(l:self)
  return !empty(getwininfo(l:self.winid))
endfunction

""
" Switch to the window using |win_gotoid()|.
"
" @throws NotFound if the window no longer exists, or if switching to the window fails.
function! {s:prefix}Goto() dict abort
  call s:CheckType(l:self)
  call s:AssertStillExists(l:self)
  if !win_gotoid(l:self.winid)
    throw maktaba#error#NotFound('failed to switch to winid: %d', l:self.winid)
  endif
endfunction
