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
" Set {setting} (explicitly qualified with g:, b:, w:, &, etc.) to {Value},
" returning its old value.
"
" If {Value} is a list or dictionary, then it will be stored by value, i.e.
" {setting} will not refer to the original {Value} passed into this function.
"
" @throws WrongType if {setting} is not a string.
function! unfocus#Exchange(setting, Value) abort
  call maktaba#ensure#IsString(a:setting)
  let l:OldVal = v:null
  execute 'let l:OldVal = '.a:setting
  execute 'let '.a:setting.' = '.string(a:Value)
  return l:OldVal
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
  for l:ShouldIgnore in s:f_IGNORE_IF.Get()
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
let s:f_IGNORE_IF = s:plugin.flags.ignore_if


""
" Check if switching/"switching" (e.g. opening a new buffer in an existing
" window, switching windows, etc.) to {winid} counts as a changed focus. If
" yes, unfocus the @dict(FocusSettings) for the last window, focus the new
" @dict(FocusSettings) for the new window, mark it as the last focused window,
" and return 1. Else, return 0.
function! unfocus#SwitchFocusIfDifferent(winid) abort
  let l:last_focus_settings = g:unfocus_last_focused.focus_settings
  let l:last_window = g:unfocus_last_focused.window_info

  let [l:new_focus_settings, l:existed] =
      \ g:unfocus_focus_settings_map.SettingsForWinID(a:winid, 'to_unfocus')
  if l:new_focus_settings is l:last_focus_settings
    return 0
  endif

  if !empty(l:last_window) && l:last_window.Exists()
    call l:last_focus_settings.Unfocus(l:last_window, s:f_WATCHED_SETTINGS.Get())
  endif

  let l:new_window = unfocus#WindowInfo#New(a:winid)
  let g:unfocus_last_focused =
      \ {'focus_settings': l:new_focus_settings, 'window_info': l:new_window}

  call l:new_focus_settings.Focus(l:new_window, s:f_WATCHED_SETTINGS.Get())

  return 1
endfunction
let s:f_WATCHED_SETTINGS = s:plugin.flags.watched_settings

""
" Begin tracking settings for all unseen windows, window-buffer pairs, or
" buffers, depending on the user's settings.
function! unfocus#AddUnseen() abort
  call g:unfocus_focus_settings_map.AddUnseen()
endfunction

function! unfocus#InitializeFocused(wininfo) abort
  call typevim#ensure#IsType(a:wininfo, 'WindowInfo')
  let l:on_new_window = s:f_ON_NEW_WINDOW.Get()
  if l:on_new_window ==# 'inherit_from_current'
    " do nothing
  elseif l:on_new_window ==# 'use_focused_settings'
    let l:on_focus = s:f_TO_SET.Get(['on_focus'])
    call a:wininfo.SetVals(l:on_focus)
  else
    throw maktaba#error#Failure(
        \ 'unknown value for on_new_window: %s', string(l:on_new_window))
  endif
endfunction
let s:f_ON_NEW_WINDOW = s:plugin.flags.on_new_window
let s:f_TO_SET = s:plugin.flags.to_set
