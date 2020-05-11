let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))

""
" Return (what should be) the first potentially valid |winid|.
"
" This value seems consistent between vim and neovim, but it isn't explicitly
" guaranteed by the documentation. The benefits of error-checking (against
" functions being given window numbers rather than |winid|s) probably
" outweigh the reliance on an undocumented constant.
function! unfocus#FirstValidWinID() abort
  return 1000
endfunction

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
" Log the given message to the vim-unfocus debug log, if debug logging is
" enabled.
function! unfocus#Log(message) abort
  if !s:f_ENABLE_DEBUG_LOGGING.Get()
    return
  endif
  call unfocus#DebugLogger#Get().Log(a:message)
endfunction
let s:f_ENABLE_DEBUG_LOGGING = s:plugin.flags.enable_debug_logging

""
" @public
" Open the vim-unfocus debug log in the current window. Also prints a warning
" message if debug logging is not enabled.
function! unfocus#OpenLog() abort
  call unfocus#DebugLogger#Get().Show()
  if !s:f_ENABLE_DEBUG_LOGGING.Get()
    call maktaba#error#Warn('Debug logging for vim-unfocus is not enabled!')
  endif
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
" window, switching windows, etc.) to {winid} with associated
" @dict(FocusSettings) {focus_settings} counts as a changed focus.
"
" If yes, unfocus the @dict(FocusSettings) for the last window, focus the new
" {focus_settings} for the new window {winid}, mark it as the last focused
" window, and return 1. Else, return 0.
function! unfocus#SwitchFocusIfDifferent(winid, focus_settings) abort
  let l:last_focus_settings = s:unfocus_last_focused.focus_settings
  let l:last_window = s:unfocus_last_focused.window_info

  if a:focus_settings is l:last_focus_settings
    return 0
  endif

  if !empty(l:last_window) && l:last_window.Exists()
    call l:last_focus_settings.Unfocus(l:last_window, s:f_WATCHED_SETTINGS.Get())
  endif

  let l:new_window = unfocus#WindowInfo#New(a:winid)
  let s:unfocus_last_focused.focus_settings = a:focus_settings
  let s:unfocus_last_focused.window_info = l:new_window

  call a:focus_settings.Focus(l:new_window, s:f_WATCHED_SETTINGS.Get())

  return 1
endfunction
let s:unfocus_last_focused = {'focus_settings': v:null, 'window_info': v:null}
let s:f_WATCHED_SETTINGS = s:plugin.flags.watched_settings

""
" Return the current @dict(FocusSettings) used to track for the current
" {winid}.
function! unfocus#CurrentFocusSettings(winid) abort
  return typevim#ensure#IsType(UnfocusGetFocusSettingsMap(), 'FocusSettingsMap')
      \.SettingsForWinID(a:winid)
endfunction

""
" Begin tracking settings for all unseen windows, window-buffer pairs, or
" buffers, depending on the user's settings.
function! unfocus#AddUnseen() abort
  call UnfocusGetFocusSettingsMap().AddUnseen()
endfunction

""
" Apply settings for a newly created window based on the value of the user's
" @flag(on_new_window).
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

""
" Returns 1 if the given {winid} corresponds to an existing window and 0
" otherwise.
"
" This function uses |winbufnr| in its implementation, but its added error
" checking protects against the accidental use of values (like most strings)
" that coerce into the numeric value 0, which |winbufnr| handles as a special
" case.
"
" @throws BadValue if {winid} is less than 1000, which seems to be the first valid |winid|.
" @throws WrongType if the given value isn't a number.
function! unfocus#WinIDExists(winid) abort
  call maktaba#ensure#IsNumber(a:winid)
  if a:winid <# unfocus#FirstValidWinID()
    throw maktaba#error#BadValue("given number isn't a valid winid: %d", a:winid)
  endif
  return s:WinIDExists(a:winid)
endfunction
if has('patch-8.1.0494') || has('nvim-0.4.0')
  " patch 0494 fixes an issue where winbufnr() and other functions won't
  " search other tabs for a given win-ID
  "
  " the has('patch-8.1.xxxx') syntax doesn't seem to work in neovim, so fall
  " back on neovim major/minor version checks instead
  function! s:WinIDExists(winid) abort
    return winbufnr(a:winid) !=# -1
  endfunction
else
  function! s:WinIDExists(winid) abort
    return win_id2tabwin(a:winid) !=# [0, 0]
  endfunction
endif
