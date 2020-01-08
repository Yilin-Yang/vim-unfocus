""
" Construct a dict encapsulating a @dict(FocusSettings) under the key
" "settings" and an associated @dict(WindowInfo) under the key "wininfo".
"
" {winid} is used to construct a @dict(WindowInfo), while "settings" is
" initialized as |v:null|.
function! unfocus#WindowState#New(winid) abort
  call maktaba#ensure#IsNumber(a:winid)
  let l:winstate = deepcopy(s:WINDOW_STATE_PROTOTYPE)
  let l:winstate.wininfo = unfocus#WindowInfo#New(a:winid)
  let l:winstate.settings = v:null
  return l:winstate
endfunction
let s:WINDOW_STATE_PROTOTYPE = typevim#make#Class(
    \ 'WindowState', {'wininfo': v:null, 'settings': v:null})
