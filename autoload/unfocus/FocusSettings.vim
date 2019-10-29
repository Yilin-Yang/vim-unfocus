""
" Encapsulates setting values to apply when a window is "focused" or
" "unfocused".  Provides member functions to update those values from a
" window's current state. Other code modules take responsibility for prompting
" FocusSettings objects to self-update.
"
" Note that bufno and winid aren't tied together by vim; one can open
" different buffers in a window without changing the window's ID.
" See `:help bufnr()` and `:help winid` for details.

let s:typename = 'FocusSettings'

""
" @private
" Construct a new FocusSettings object.
function! unfocus#FocusSettings#New(bufno, winid) abort
  let l:new = {
    \ '_set_when_focused': {},
    \ '_set_when_unfocused': {},
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
