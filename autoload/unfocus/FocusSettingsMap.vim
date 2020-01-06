""
" Mapping between window IDs and their associated @dict(FocusSettings). Handles
" retrieval of constructed FocusSettings, and construction of new
" FocusSettings objects when one doesn't exist.
"
" Handling of @flag(store_settings_per) is done by making
" @dict(FocusSettingsMap) polymorphic, and by having the plugin call
" @function(SettingsForWinID) to look up FocusSettings for a window that is
" being entered. Derived classes should override SettingsForWinID() to
" customize this behavior.
"
" This class is the "standard" implementation that stores a FocusSettings
" per each window-ID.
"
" The identity of the returned FocusSettings determines whether a
" "switch" has taken place and the unfocus/focus swap should fire.

let s:typename = 'FocusSettingsMap'

""
" Construct a new FocusSettingsMap from {InitWindow}, a callable
" that takes in a @dict(WindowInfo) and initializes the window as an
" "unfocused" window prior to the construction of a dict(FocusSettings)
" object, and a @dict(Flag) of settings {to_set} structured like @flag(to_set).
"
" @throws WrongType if {InitWindow} is not a function or {to_set} is not a @dict(Flag) objects.
function! unfocus#FocusSettingsMap#New(to_set) abort
  let l:new = {
      \ 'SettingsForWinID':
        \ typevim#make#AbstractFunc(
            \ s:typename, 'SettingsForWinID', ['winid']),
      \ '_MakeFocusSettingsForWin': typevim#make#Member('_MakeFocusSettingsForWin'),
      \ 'AddUnseen': typevim#make#AbstractFunc(s:typename, 'AddUnseen', []),
      \ 'to_set': s:EnsureIsMaktabaFlag(a:to_set),
      \ }
  return typevim#make#Class(s:typename, l:new)
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! s:EnsureIsMaktabaFlag(Obj) abort
  return typevim#ensure#Implements(a:Obj, s:FLAG_INTERFACE)
endfunction
let s:FLAG_INTERFACE = typevim#make#Interface(
    \ 'maktaba#Flag', {
        \ 'Get': typevim#Func(),
        \ 'GetCopy': typevim#Func(),
        \ 'Set': typevim#Func(),
        \ 'AddCallback': typevim#Func(),
        \ 'Translate': typevim#Func(),
        \ }
    \ )

""
" Construct a @dict(FocusSettings) for {wininfo}, initializing the window as if
" it were of the given {kind}, and return it.
"
" {kind} may be 'to_unfocus', 'focused', or 'unfocused'.
"
" @throws BadValue if {kind} is not one of the values from above.
" @throws WrongType if {wininfo} is not a @dict(WindowInfo) or {kind} is not a string.
function! unfocus#FocusSettingsMap#_MakeFocusSettingsForWin(wininfo, kind) dict abort
  call typevim#ensure#IsType(a:wininfo, 'WindowInfo')
  call maktaba#ensure#IsString(a:kind)
  if a:kind ==# 'to_unfocus'
    let l:settings = unfocus#FocusSettings#FromToUnfocus(
        \ a:wininfo, l:self.to_set.Get(['on_unfocus']))
  elseif a:kind ==# 'focused'
    let l:settings = unfocus#FocusSettings#FromFocused(
        \ a:wininfo, l:self.to_set.Get(['on_unfocus']))
  elseif a:kind ==# 'unfocused'
    let l:settings = unfocus#FocusSettings#FromUnfocused(
        \ a:wininfo, l:self.to_set.Get(['on_focus']))
  else
    throw maktaba#error#BadValue('bad value for {kind}: %s', a:kind)
  endif
  return l:settings
endfunction
