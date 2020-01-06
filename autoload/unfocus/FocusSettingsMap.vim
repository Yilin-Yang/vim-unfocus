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
" This base class is the "standard" implementation that stores a FocusSettings
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
function! unfocus#FocusSettingsMap#New(to_set, InitWindow) abort
  let l:new = {
      \ 'SettingsForWinID': typevim#make#Member('SettingsForWinID'),
      \ 'AddUnseen': typevim#make#Member('AddUnseen'),
      \ '__InitWindow': maktaba#ensure#IsFuncref(a:InitWindow),
      \ '__to_set': s:EnsureIsMaktabaFlag(a:to_set),
      \ '__winid_to_winstate': {},
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
" Helper class: encapsulates a @dict(WindowInfo) for {winid} and the
" associated @dict(FocusSettings), both of which are built in this function.
" The FocusSettings is constructed through a call to
" @function(unfocus#FocusSettings#FromToUnfocus) using {on_unfocus}, while
" {InitWindow} is invoked to perform setup for the new window.
function! s:WindowState_NewToUnfocus(winid, InitWindow, on_unfocus) abort
  let l:new = deepcopy(s:WINDOW_STATE_PROTOTYPE)
  let l:new.wininfo = unfocus#WindowInfo#New(a:winid)
  call a:InitWindow(l:new.wininfo)
  let l:new.settings =
      \ unfocus#FocusSettings#FromToUnfocus(l:new.wininfo, a:on_unfocus)
  return l:new
endfunction

""
" Like @function(s:WindowState_NewToUnfocus), but treats the given {winid} as
" a window that is presently unfocused. Takes settings to set {on_focus},
" which are passed to @function(unfocus#FocusSettings#FromUnfocused).
function! s:WindowState_NewUnfocused(winid, on_focus) abort
  let l:new = deepcopy(s:WINDOW_STATE_PROTOTYPE)
  let l:new.wininfo = unfocus#WindowInfo#New(a:winid)
  let l:new.settings =
      \ unfocus#FocusSettings#FromUnfocused(l:new.wininfo, a:on_focus)
  return l:new
endfunction

""
" Like @function(s:WindowState_NewFocused), but treats the given {winid} as
" a window that is presently focused. Takes settings to set {on_unfocus},
" which are passed to @function(unfocus#FocusSettings#FromUnfocused).
function! s:WindowState_NewFocused(winid, on_unfocus) abort
  let l:new = deepcopy(s:WINDOW_STATE_PROTOTYPE)
  let l:new.wininfo = unfocus#WindowInfo#New(a:winid)
  let l:new.settings =
      \ unfocus#FocusSettings#FromFocused(l:new.wininfo, a:on_unfocus)
  return l:new
endfunction

let s:WINDOW_STATE = 'WindowState'
let s:WINDOW_STATE_PROTOTYPE = typevim#make#Class(
    \ s:WINDOW_STATE, {'wininfo': v:null, 'settings': v:null})

""
" Produce a @dict(FocusSettings) object for {winid}.
"
" Return the retrieved FocusSettings object.
"
" May also take a [construct_as] parameter, which may be "to_unfocus" or
" "default_unfocused": this controls behavior when the FocusSettings object
" doesn't already exist. The former treats the {winid} as an already-focused
" window to be unfocused; this stores the current watched setting values as
" the window's focused settings. The latter treats the {winid} as a currently
" unfocused window if {winid} is not the focused window, and stores the
" current watched setting values as the window's unfocused settings; if
" {winid} is the focused window, it treats the window as an already-focused
" window.
"
" @default construct_as=`"to_unfocus"`
"
" @throws BadValue if [construct_as] is invalid.
" @throws WrongType if {winid} is not a number or [construct_as] is not a string.
function! unfocus#FocusSettingsMap#SettingsForWinID(winid, ...) dict abort
  call s:CheckType(l:self)
  let l:construct_as = get(a:000, 0, 'to_unfocus')

  let l:winstate = get(l:self.__winid_to_winstate, a:winid, v:null)
  if l:winstate is v:null
    " construct the new FocusSettings object
    let l:existed = 0
    if l:construct_as ==# 'to_unfocus'
      let l:winstate = s:WindowState_NewToUnfocus(
          \ a:winid, l:self.__InitWindow, l:self.__to_set.Get(['on_unfocus']))
    elseif l:construct_as ==# 'default_unfocused'
      if a:winid ==# win_getid()
        let l:winstate = s:WindowState_NewFocused(
            \ a:winid, l:self.__to_set.Get(['on_focus']))
      else
        let l:winstate = s:WindowState_NewUnfocused(
            \ a:winid, l:self.__InitWindow, l:self.__to_set.Get(['on_unfocus']))
      endif
    else
      throw maktaba#error#BadValue(
          \ 'unrecognized value for construct_as: %s', l:construct_as)
    endif
    let l:self.__winid_to_winstate[a:winid] = l:winstate
  endif
  return l:winstate.settings
endfunction

""
" Generate @dict(FocusSettings) objects for all "unregistered" windows,
" buffers, or window/buffer pairs.
function! unfocus#FocusSettingsMap#AddUnseen() dict abort
  call s:CheckType(l:self)
  let l:tabinfos = gettabinfo()
  for l:tabinfo in l:tabinfos | for l:winid in l:tabinfo.windows
    call l:self.SettingsForWinID(l:winid, 'default_unfocused')
  endfor | endfor
endfunction
