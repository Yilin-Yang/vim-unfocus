""
" Mapping between window IDs and their associated @dict(FocusSettings). Handles
" retrieval of constructed FocusSettings, and construction of new
" FocusSettings objects when one doesn't exist.
"
" This class is the "standard" implementation that stores a FocusSettings
" per each window-ID.
"
" The identity of the returned FocusSettings determines whether a
" "switch" has taken place and the unfocus/focus swap should fire.
" This was originally meant to make "focus switched" detection more flexible
" (by allowing, e.g. the opening of a new buffer in the same window to count
" as a "focus switch"), but that was set aside since it seems that we would
" need to track much more state (e.g. whether the "window" being "left" still
" holds the cursor) for that to work properly.

let s:typename = 'FocusSettingsMap'
let s:prefix = 'unfocus#FocusSettingsMap#'

""
" Construct a new FocusSettingsMap from {InitWindow}, a callable
" that takes in a @dict(WindowInfo) and initializes the window as an
" "unfocused" window prior to the construction of a dict(FocusSettings)
" object, and a @dict(Flag) of settings {to_set} structured like @flag(to_set).
"
" @throws WrongType if {InitWindow} is not a function or {to_set} is not a @dict(Flag) objects.
function! {s:prefix}New(to_set, InitWindow) abort
  let l:new = {
      \ 'SettingsForWinID': typevim#make#Member('SettingsForWinID'),
      \ '_MakeFocusSettingsForWin': typevim#make#Member('_MakeFocusSettingsForWin'),
      \ 'RemoveSettingsForWinID': typevim#make#Member('RemoveSettingsForWinID'),
      \ 'SettingsExistForWinID': typevim#make#Member('SettingsExistForWinID'),
      \ 'AddUnseen': typevim#make#Member('AddUnseen'),
      \ 'GarbageCollect': typevim#make#Member('GarbageCollect'),
      \ 'to_set': s:EnsureIsMaktabaFlag(a:to_set),
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
" Construct a @dict(FocusSettings) for {wininfo}, initializing the window as if
" it were of the given {kind}, and return it.
"
" {kind} may be 'to_unfocus', 'focused', or 'unfocused'.
"
" @throws BadValue if {kind} is not one of the values from above.
" @throws WrongType if {wininfo} is not a @dict(WindowInfo) or {kind} is not a string.
function! {s:prefix}_MakeFocusSettingsForWin(wininfo, kind) dict abort
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
function! {s:prefix}SettingsForWinID(winid, ...) dict abort
  call s:CheckType(l:self)
  let l:construct_as = get(a:000, 0, 'to_unfocus')

  let l:winstate = get(l:self.__winid_to_winstate, a:winid, v:null)
  if l:winstate is v:null
    " construct the new FocusSettings object
    let l:wininfo = unfocus#WindowInfo#New(a:winid)
    let l:winstate = deepcopy(s:WINDOW_STATE_PROTOTYPE)
    let l:winstate.wininfo = l:wininfo
    if l:construct_as ==# 'to_unfocus'
      let l:winstate.settings =
          \ l:self._MakeFocusSettingsForWin(l:wininfo, 'to_unfocus')
    elseif l:construct_as ==# 'default_unfocused'
      if a:winid ==# win_getid()
        let l:winstate.settings =
            \ l:self._MakeFocusSettingsForWin(l:wininfo, 'focused')
      else
        let l:winstate.settings =
            \ l:self._MakeFocusSettingsForWin(l:wininfo, 'unfocused')
      endif
    else
      throw maktaba#error#BadValue(
          \ 'unrecognized value for construct_as: %s', l:construct_as)
    endif
    let l:self.__winid_to_winstate[a:winid] = l:winstate
  endif
  return l:winstate.settings
endfunction
let s:WINDOW_STATE_PROTOTYPE = typevim#make#Class(
    \ 'WindowState', {'wininfo': v:null, 'settings': v:null})

""
" Remove the @dict(FocusSettings) for {winid}. Used as a cleanup operation.
" Returns 1 if a @dict(FocusSettings) had been removed, 0 otherwise.
function! {s:prefix}RemoveSettingsForWinID(winid) dict abort
  call s:CheckType(l:self)
  if has_key(l:self.__winid_to_winstate, a:winid)
    unlet l:self.__winid_to_winstate[a:winid]
    return 1
  endif
  return 0
endfunction

""
" Return 1 if a @dict(FocusSettings) exists for {winid} and 0 otherwise.
function! {s:prefix}SettingsExistForWinID(winid) dict abort
  return has_key(l:self.__winid_to_winstate, a:winid)
endfunction

""
" Generate @dict(FocusSettings) objects for all "unregistered" windows,
" buffers, or window/buffer pairs.
function! {s:prefix}AddUnseen() dict abort
  call s:CheckType(l:self)
  let l:tabinfos = gettabinfo()
  for l:tabinfo in l:tabinfos | for l:winid in l:tabinfo.windows
    try
      call l:self.SettingsForWinID(l:winid, 'default_unfocused')
    catch /ERROR(NotFound)/
    endtry
  endfor | endfor
endfunction

""
" Remove the @dict(FocusSettings) for all |winid| entries that no longer exist
" in the object's internal dict.
function! {s:prefix}GarbageCollect() dict abort
  call s:CheckType(l:self)
  for l:winid in keys(l:self.__winid_to_winstate)
    if unfocus#WinIDExists(l:winid)
      continue
    endif
    unlet l:self.__winid_to_winstate[l:winid]
  endfor
endfunction
