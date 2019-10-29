
""
" @private
" Return true if the |window| given {winid} (as returned by |win_getid()| is
" focused, false otherwise.
"
" @throws WrongType if {winid} is not a number.
function! unfocus#IsFocused(winid) abort
  call maktaba#ensure#IsNumber(a:winid)
  return win_getid() == a:winid
endfunction

""
" @private
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
" @private
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
" @private
" Calls {ToCall} @function(unfocus#With) lazyredraw set to true.
function! unfocus#WithLazyRedraw(ToCall, ...) abort
  return call('unfocus#With', ['&lazyredraw', 1, a:ToCall] + a:000)
endfunction
