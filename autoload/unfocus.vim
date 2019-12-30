let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))

""
" Return true if the |window| given {winid} (as returned by |win_getid()| is
" focused, false otherwise.
"
" @throws WrongType if {winid} is not a number.
function! unfocus#IsFocused(winid) abort
  call maktaba#ensure#IsNumber(a:winid)
  return win_getid() == a:winid
endfunction

""
" Set {setting} (explicitly qualified with g:, b:, w:, &, etc.) to {value},
" returning its old value.
"
" If {value} is a list or dictionary, then it will be stored by value, i.e.
" {setting} will not refer to the original {value} passed into this function.
"
" @throws WrongType if {setting} is not a string.
function! unfocus#Exchange(setting, value) abort
  call maktaba#ensure#IsString(a:setting)
  let l:old_val = v:null
  execute 'let l:old_val = '.a:setting
  execute 'let '.a:setting.' = '.string(a:value)
  return l:old_val
endfunction

""
" Invoke the function {ToCall} with [arguments] with {setting} set to {value},
" and restore {setting} to its old value after {ToCall} returns regardless
" of whether it exited with error.
"
" Returns the return value of {ToCall}.
function! unfocus#With(setting, value, ToCall, ...) abort
  call maktaba#ensure#IsFuncref(a:ToCall)
  let l:old = unfocus#Exchange(a:setting, a:value)
  try
    return call(a:ToCall, a:000)
  finally
    call unfocus#Exchange(a:setting, l:old)
  endtry
endfunction

""
" Calls {ToCall} @function(unfocus#With) lazyredraw set to true.
function! unfocus#WithLazyRedraw(ToCall, ...) abort
  return call('unfocus#With', ['&lazyredraw', 1, a:ToCall] + a:000)
endfunction

""
" @public
" Given a {winid}, return the value of {variable} within that window, or
" [default] if that variable has no defined value.
"
" Acts as a convenience wrapper that automatically converts the given |winid|
" into a tabnr and winnr, which it then passes (along with {variable} and
" [default]) to |gettabwinvar()|.
function! unfocus#WinVarFromID(winid, variable, ...) abort
  call maktaba#ensure#IsString(a:variable)
  let l:tab_and_winnr = win_id2tabwin(a:winid)
  return call('gettabwinvar', l:tab_and_winnr + [a:variable] + a:000)
endfunction


""
" Given a {winid} that the user has just entered, return 1 if vim-unfocus
" should ignore it (i.e. one or more of the given callables returns truthy)
" and 0 otherwise.
"
function! unfocus#ShouldIgnore(winid) abort
  for l:ShouldIgnore in s:IGNORE_IF.Get()
    try
      if l:ShouldIgnore(a:winid)
        return 1
      endif
    catch
      throw maktaba#error#Failure(
          \ 'ignore_if callable %s threw exception on winid %s: %s, %s',
          \ string(l:ShouldIgnore), a:winid, v:throwpoint, v:exception)
    endtry
  endfor
  return 0
endfunction
let s:IGNORE_IF = s:plugin.flags.ignore_if
