""
" Functions and state used for cleaning up @dict(FocusSettings) objects for
" windows that no longer exist.
"
" This relies on obnoxious workarounds due to the lack of a WinClosed event,
" and because |TabClosed| and |TabLeave| doesn't necessarily work the way that
" you would expect.
"
" In the latter case, |TabClosed| only fires when the entire
" tab is already closed. As a tab is being closed, |WinLeave| events fire for
" each still-open window (as they're apparently closed one-by-one) so that,
" when the |TabLeave| triggers, only the very last window remains open. These
" work to prevent us from logging all still-open windows when the tab closes
" and performing cleanup work only for those.
"
" Whenever a |WinLeave| event occurs, we store the |winid| of the just-left
" window (because WinLeave triggers before a window is closed). On |WinEnter|,
" we check whether that stored |winid| still exists; if not, then it must have
" been closed, so we clean up that |winid|.
"
" Whenever a |WinNew| event occurs, we store the |winid| in a dictionary for
" that tabpage. This means that, when |TabClosed| finally fires, we know every
" |winid| that had ever been shown in tabpage; this lets us exhaustively clean
" up each window that still had a stored @dict(FocusSettings).

let s:prefix = 'unfocus#cleanup#'

""
" Store the |winid| of a window being left, as during a |WinLeave| event.
" Later, we can check if that window still exists; if it doesn't, we can
" trigger cleanup for that window's state.
function! {s:prefix}MarkLeavingWindow(winid) abort
  let s:last_left_window = a:winid
endfunction
let s:last_left_window = unfocus#FirstValidWinID()

""
" Read in {Tabpagenr}, which should be either a string (coercable into a
" number) or a number. Perform type checking and return the given value as a
" number.
"
" @throws BadValue if {Tabpagenr} is negative.
" @throws WrongType if {Tabpagenr} is not a number or a string that can be coerced into a positive number.
function! s:ValidateTabPageNr(Tabpagenr) abort
  if maktaba#value#IsString(a:Tabpagenr)
    let l:tabpagenr = a:Tabpagenr + 0
  elseif maktaba#value#IsNumber(a:Tabpagenr)
    let l:tabpagenr = a:Tabpagenr
  else
    throw maktaba#error#WrongType(
        \ 'wrong type for a tabpagenr: %s', string(a:Tabpagenr))
  endif
  if l:tabpagenr <# 1
    throw maktaba#error#BadValue(
        \ 'cannot give a non-positive tabpagenr: %s', a:Tabpagenr)
  endif
  return l:tabpagenr
endfunction

""
" Log that {winid} has been opened in {tabpagenr}.
function! {s:prefix}MarkNewWindowInTab(winid, tabpagenr)
  let l:tabpagenr = s:ValidateTabPageNr(a:tabpagenr)
  let l:winid_set = get(s:tabpagenr_to_winid_set, l:tabpagenr, v:null)
  if l:winid_set is v:null
    let l:winid_set = {}
    let s:tabpagenr_to_winid_set[l:tabpagenr] = l:winid_set
  endif
  let l:winid_set[a:winid] = v:null
endfunction

""
" Dictionary between every tabpagenr and every window-ID that might still be
" open in that tabpage, as a dict between |winid| and |v:null|.
let s:tabpagenr_to_winid_set = {}

""
" If the last left window no longer exists, perform cleanup work for it.
function! {s:prefix}CleanUpLeftWindowIfClosed() abort
  if unfocus#WinIDExists(s:last_left_window)
    return
  endif
  call UnfocusGetFocusSettingsMap().RemoveSettingsForWinID(s:last_left_window)
endfunction

""
" Perform cleanup work for all of the |winid|s that might have been open in the
" given {tabpagenr}.
function! {s:prefix}CleanUpClosedTab(tabpagenr) abort
  let l:tabpagenr = s:ValidateTabPageNr(a:tabpagenr)
  let l:winids = get(s:tabpagenr_to_winid_set, l:tabpagenr, {})
  let l:focus_settings_map = UnfocusGetFocusSettingsMap()
  for l:winid in keys(l:winids)
    call l:focus_settings_map.RemoveSettingsForWinID(l:winid)
  endfor
  unlet s:tabpagenr_to_winid_set[l:tabpagenr]
endfunction

""
" Perform an exhaustive garbage collection of every @dict(FocusSettings)
" object that corresponds to a |winid| that no longer exists. Should be
" triggered only rarely.
function! {s:prefix}GarbageCollect() abort
  call UnfocusGetFocusSettingsMap().GarbageCollect()
endfunction
