""
" @private
" @dict WindowInfo
"
" Helper object for uniquely identifying a window.
"
" Contains a `bufno` and a `winid`. Combined, these can represent the state of a
" buffer being currently open in a particular window. In practice, only the
" `winid` is necessary for lookup, though the `bufno` may be useful for error
" checking.

let s:typename = 'WindowInfo'

""
" @private
" Construct a new WindowInfo object from a {winid} (as returned by a function
" like |win_getid()|) and an optional [bufno] (as returned by a function like
" |bufnr()|).
"
" @throws NotFound if {winid} doesn't correspond to an existing window.
" @throws WrongType if {winid} is not a number, or if [bufno] is not a number or v:null.
function! unfocus#WindowInfo#New(winid, ...) dict abort
  let l:bufno = get(a:000, 0, v:null)
  let l:new = {
      \ 'bufno': maktaba#ensure#TypeMatchesOneOf(l:bufno, [0, v:null]),
      \ 'winid': maktaba#ensure#IsNumber(a:winid),
      \ 'tabnr': v:null,
      \ 'getwinvar': typevim#make#Member('getwinvar'),
      \ 'setwinvar': typevim#make#Member('setwinvar'),
      \ 'GetVals': typevim#make#Member('GetVals'),
      \ 'SetVals': typevim#make#Member('SetVals'),
      \ 'Exists': typevim#make#Member('Exists'),
      \ }

  let l:new.tabnr = win_id2tabwin(a:winid)[0]
  if l:new.tabnr ==# 0
    throw maktaba#error#NotFound(
        \ printf('Could not find tabpage for window %d', a:winid))
  endif

  return typevim#make#Class(s:typename, l:new)
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

""
" @private
" Retrieve the value of a particular variable (window-local setting,
" window-local variable, etc.) for this window. Returns [default] if no value
" could be retrieved.
"
" @default default=`""`, the empty string.
"
" @throws NotFound if the window no longer exists.
" @throws WrongType if {varname} is not a string.
function! unfocus#WindowInfo#getwinvar(varname, ...) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsString(a:varname)
  let l:default = get(a:000, 0, '')

  if !self.Exists()
    throw maktaba#error#NotFound(
        \ printf('Window %d no longer exists', l:self.winid))
  endif

  return gettabwinvar(l:self.tabnr, l:self.winid, a:varname, l:default)
endfunction

""
" @private
" Set the value of a variable {varname} to {val} in this window.
"
" @throws NotFound if the window no longer exists.
" @throws WrongType if {varname} is not a string.
function! unfocus#WindowInfo#setwinvar(varname, val) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsString(a:varname)
  call settabwinvar(l:self.tabnr, l:self.winid, a:varname, a:val)
endfunction

""
" @private
" Given {for_vars}, return a dict between those variables and
" their current values for the window..
"
" @throws WrongType if {for_vars} is not a list of strings.
function! unfocus#WindowInfo#GetVals(for_vars) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#IsList(a:for_vars)
  let l:current_vals = {}
  for l:varname in a:for_vars
    call maktaba#ensure#IsString(l:varname)
    let l:current_vals[l:varname] = l:self.getwinvar(l:varname)
  endfor
  return l:current_vals
endfunction

""
" @private
" Set the current values of the variabless {vars_and_vals} in this Window and
" return the old values of those variables.
"
" Strong guarantee: if an exception is thrown while setting variable values,
" all variables that had been updated until that point will be restored to
" their prior values.
"
" @throws WrongType if {vars_and_vals} is not a dict.
function! unfocus#WindowInfo#SetVals(vars_and_vals) dict abort
  call s:CheckType(l:self)
  call maktaba#ensure#isDict(a:vars_and_vals)
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
    throw v:exception
  endtry
  return l:old_vals
endfunction

""
" @private
" Return true if the managed window still exists and false otherwise.
function! unfocus#WindowInfo#Exists() dict abort
  call s:CheckType(l:self)
  return !empty(getwininfo(l:self.winid))
endfunction
