""
" Encapsulates setting values to apply when a window is "focused" or
" "unfocused".  Provides member functions to update those values from a
" window's current state. Other code modules take responsibility for prompting
" FocusSettings objects to self-update.
"
" FocusSettings does not (publicly) expose a "side-effect-free" constructor,
" since (by design) one of the two "set_when_*" dicts will be overwritten with
" whatever setting values were replaced by the most recent call to Focus() or
" Unfocus().
"
" It is assumed that the {winid} passed into the FocusSettings constructor is
" "already focused", i.e. the current setting values for the window are those
" that the user wants to be set for a "focused" window.

let s:typename = 'FocusSettings'

""
" @private
" Construct a FocusSettings object from a {winid}. The current values of the
" watched settings (the keys of {set_when_unfocused}) are used to initialize
" the "set_when_focused" member dict.
function! unfocus#FocusSettings#AlreadyFocused(wininfo, set_when_unfocused) abort
  return unfocus#WithLazyRedraw(
      \ function('s:AlreadyFocused'), a:wininfo, a:set_when_unfocused)
endfunction
function! s:AlreadyFocused(wininfo, set_when_unfocused) abort
  let l:new = unfocus#FocusSettings#_New({}, a:set_when_unfocused)
  let l:to_set = keys(a:set_when_unfocused)
  call l:new.Unfocus(a:wininfo, l:to_set)  " store current vals for Focused...
  call l:new.Focus(a:wininfo, l:to_set)  " ...but then refocus the window
  return l:new
endfunction

""
" @private
" Construct a FocusSettings object and immediately Unfocus {winid} with
" {set_when_unfocused}, using the old setting values to populate the
" "set_when_focused" dict.
function! unfocus#FocusSettings#FromToUnfocus(wininfo, set_when_unfocused) abort
  return unfocus#WithLazyRedraw(
      \ function('s:FromToUnfocus'), a:wininfo, a:set_when_unfocused)
endfunction
function! s:FromToUnfocus(wininfo, set_when_unfocused)
  let l:new = unfocus#FocusSettings#_New({}, a:set_when_unfocused)
  let l:to_set = keys(a:set_when_unfocused)
  call l:new.Unfocus(a:wininfo, l:to_set)  " store current vals for Focused
  return l:new
endfunction

""
" @private
" Construct a new FocusSettings object.
"
" Must specify a {set_when_focused} dict and a (set_when_unfocused) dict as
" arguments; these are dictionaries between variable/setting names (as would
" be passed to functions like |getwinvar()|) and their desired values when
" the window is focused or unfocused, respectively.
"
" Note that {set_when_focused} or {set_when_unfocused} will be
" clobbered as soon as Unfocus() or Focus() are called, respectively. For this
" reason, this constructor isn't "public".
"
" @throws WrongType if either argument is not a dict.
function! unfocus#FocusSettings#_New(set_when_focused, set_when_unfocused) abort
  call maktaba#ensure#IsDict(a:set_when_focused)
  call maktaba#ensure#IsDict(a:set_when_unfocused)
  let l:new = {
    \ '__set_when_focused': copy(a:set_when_focused),
    \ '__set_when_unfocused': copy(a:set_when_unfocused),
    \ 'Focus': typevim#make#Member('Focus'),
    \ 'Unfocus': typevim#make#Member('Unfocus'),
    \ }
  call typevim#make#Class(s:typename, l:new)
  return l:new
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

""
" @private
" Implementation of @function(unfocus#FocusSettings#Focus) and
" @function(unfocus#FocusSettings#Unfocus).
"
" Given {focus_settings}, use settings {to_set} and a settings-values dict
" {from} to @function(unfocus#WindowInfo#SetVals) in {target_win}. Return a
" settings-values dict of the old values.
function! s:FocusUnfocusImpl(focus_settings, target_win, to_set, from) abort
  call s:CheckType(a:focus_settings)
  call typevim#ensure#IsType(a:target_win, 'WindowInfo')
  call maktaba#ensure#IsList(a:to_set)
  call maktaba#ensure#IsDict(a:from)

  let l:vars_and_vals_to_set = {}

  " if we don't have a stored value for a particular variable, then retrieve
  " it separately
  let l:vars_to_get = []

  let l:not_present = []  " used to detect missing items in the dict
  for l:var in a:to_set
    call maktaba#ensure#IsString(l:var)
    let l:val = get(a:from, l:var, l:not_present)
    if l:val is l:not_present
      call add(l:vars_to_get, l:var)
    else
      let l:vars_and_vals_to_set[l:var] = l:val
    endif
  endfor

  let l:old_vals = a:target_win.SetVals(l:vars_and_vals_to_set)
  if len(l:not_present)
    call extend(l:old_vals, a:target_win.GetVals(l:vars_to_get), 'error')
  endif

  return l:old_vals
endfunction

""
" @private
" Given {wininfo_to_focus}, store the current values of the settings {to_set}
" as "unfocused values" and restore the values of {to_set} from the "focused
" values".
"
" @throws WrongType if {wininfo_to_focus} is not a @dict(WindowInfo), or if {to_set} is not a list of strings.
function! unfocus#FocusSettings#Focus(wininfo_to_focus, to_set) dict abort
  call s:CheckType(l:self)
  call typevim#ensure#IsType(a:wininfo_to_focus, 'WindowInfo')
  call maktaba#ensure#IsList(a:to_set)
  let l:self.__set_when_unfocused = s:FocusUnfocusImpl(
      \ l:self, a:wininfo_to_focus, a:to_set, l:self.__set_when_focused)
endfunction

""
" @private
" Given {wininfo_to_unfocus}, store the current values of the settings {to_set}
" as "focused values" and restore the values of {to_set} from the "unfocused
" values".
"
" @throws WrongType if {wininfo_to_unfocus} is not a @dict(WindowInfo), or if {to_set} is not a list of strings.
function! unfocus#FocusSettings#Unfocus(wininfo_to_unfocus, to_set) dict abort
  call s:CheckType(l:self)
  call typevim#ensure#IsType(a:wininfo_to_unfocus, 'WindowInfo')
  call maktaba#ensure#IsList(a:to_set)
  let l:self.__set_when_focused = s:FocusUnfocusImpl(
      \ l:self, a:wininfo_to_unfocus, a:to_set, l:self.__set_when_unfocused)
endfunction
