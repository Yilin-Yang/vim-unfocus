""
" Mapping between window IDs and their associated @dict(FocusSettings).
"
" This class is the "standard" implementation that stores a FocusSettings
" per each window-ID.

let s:typename = 'WindowFocusSettingsMap'
let s:prefix = 'unfocus#WindowFocusSettingsMap#'

""
" Construct a new WindowFocusSettingsMap from {InitWindow}, a callable
" that takes in a @dict(WindowInfo) and initializes the window as an
" "unfocused" window prior to the construction of a dict(FocusSettings)
" object, and a @dict(Flag) of settings {to_set} structured like @flag(to_set).
"
" @throws WrongType if {InitWindow} is not a function or {to_set} is not a @dict(Flag) objects.
function! {s:prefix}New(to_set, InitWindow) abort
  let l:base = unfocus#FocusSettingsMap#New(a:to_set)
  let l:new = {
      \ 'SettingsForWinID': typevim#make#Member('SettingsForWinID'),
      \ 'AddUnseen': typevim#make#Member('AddUnseen'),
      \ '_InitWindow': maktaba#ensure#IsFuncref(a:InitWindow),
      \ '__winid_to_winstate': {},
      \ }
  return typevim#make#Derived(s:typename, l:base, l:new)
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

""
" "Templated" implementation of SettingsForWinID.
"
" {self} is the WindowFocusSettingsMap. {dict} is the dictionary in which to
" look up an existing @dict(WindowState). {WinidToKey} is a function that
" takes in a {winid} and converts it into the key used for lookup in {dict}.
" {winid} and [construct_as] are the same as in SettingsForWinID.
function! {s:prefix}_SettingsForWinID(self, dict, WinidToKey, winid, ...) abort
  call s:CheckType(a:self)
  let l:construct_as = get(a:000, 0, 'to_unfocus')
  let l:InitWindow = a:self._InitWindow

  let l:key = a:WinidToKey(a:winid)
  let l:winstate = get(a:dict, l:key, v:null)
  if l:winstate is v:null
    " construct the new FocusSettings object
    let l:winstate = unfocus#WindowState#New(a:winid)
    let l:wininfo = l:winstate.wininfo
    call l:InitWindow(l:wininfo)
    if l:construct_as ==# 'to_unfocus'
      let l:winstate.settings =
          \ a:self._MakeFocusSettingsForWin(l:wininfo, 'to_unfocus')
    elseif l:construct_as ==# 'default_unfocused'
      if a:winid ==# win_getid()
        let l:winstate.settings =
            \ a:self._MakeFocusSettingsForWin(l:wininfo, 'focused')
      else
        let l:winstate.settings =
            \ a:self._MakeFocusSettingsForWin(l:wininfo, 'unfocused')
      endif
    else
      throw maktaba#error#BadValue(
          \ 'unrecognized value for construct_as: %s', l:construct_as)
    endif
    let a:dict[l:key] = l:winstate
  endif
  return l:winstate.settings
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
  return call(
      \ 'unfocus#WindowFocusSettingsMap#_SettingsForWinID',
      \ [l:self, l:self.__winid_to_winstate, { winid -> winid }, a:winid]
          \ + a:000)
endfunction

""
" Generate @dict(FocusSettings) objects for all "unregistered" windows,
" buffers, or window/buffer pairs.
function! {s:prefix}AddUnseen() dict abort
  call s:CheckType(l:self)
  let l:tabinfos = gettabinfo()
  for l:tabinfo in l:tabinfos | for l:winid in l:tabinfo.windows
    call l:self.SettingsForWinID(l:winid, 'default_unfocused')
  endfor | endfor
endfunction
