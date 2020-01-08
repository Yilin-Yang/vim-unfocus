""
" Mapping between paired window IDs and buffer numbers and their associated
" @dict(FocusSettings).

let s:typename = 'WindowBufferFocusSettingsMap'
let s:prefix = printf('unfocus#%s#', s:typename)

""
" Construct a new WindowBufferFocusSettingMap from {to_set}, which should be
" the @flag(to_set), and an {InitWindow} function.
function! {s:prefix}New(to_set, InitWindow) abort
  let l:base = unfocus#WindowFocusSettingsMap#New(a:to_set, a:InitWindow)
  let l:new = {
      \ 'SettingsForWinID': typevim#make#Member('SettingsForWinID'),
      \ 'AddUnseen': typevim#make#Member('AddUnseen'),
      \ '__winbuf_to_winstate': {},
      \ }
  return typevim#make#Derived(s:typename, l:base, l:new)
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! s:ToWinBuf(winid) abort
  let l:bufnr = winbufnr(maktaba#ensure#IsNumber(a:winid))
  if l:bufnr ==# -1
    throw maktaba#error#NotFound('bufnr lookup failed for winid: %d', a:winid)
  endif
  return printf('%d:%d', a:winid, l:bufnr)
endfunction

""
" See @function(unfocus#WindowFocusSettingsMap#SettingsForWinID).
function! {s:prefix}SettingsForWinID(winid, ...) dict abort
  call s:CheckType(l:self)
  return call(
      \ 'unfocus#WindowFocusSettingsMap#_SettingsForWinID',
      \ [l:self, l:self.__winbuf_to_winstate, function('s:ToWinBuf'), a:winid]
          \ + a:000)
endfunction
