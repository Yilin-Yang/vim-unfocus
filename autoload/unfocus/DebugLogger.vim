""
" Global singleton debug logger.

let s:typename = 'DebugLogger'
let s:prefix = 'unfocus#DebugLogger#'

""
" Return a reference to the debug logger singleton.
function! {s:prefix}Get() abort
  if !exists('s:vim_unfocus_debug_logger')
    let s:vim_unfocus_debug_logger = typevim#make#Class(
        \ s:typename, {
          \ 'buffer': typevim#Buffer#New({
          \ 'bufname': 'vim-unfocus Debug Log',
          \ }),
        \ 'Log': function(s:prefix.'Log'),
        \ 'Show': function(s:prefix.'Show'),
        \ })
  endif
  return s:vim_unfocus_debug_logger
endfunction

function! s:CheckType(Obj) abort
  call typevim#ensure#IsType(a:Obj, s:typename)
endfunction

function! s:GetTimestamp() abort
  let l:to_return = ''
  if exists('*strftime')
    let l:to_return .= strftime('%c').' '
  endif
  let l:to_return .= reltimestr(reltime())
  return l:to_return
endfunction

""
" Log a message to the debug buffer.
function! {s:prefix}Log(message) dict abort
  call s:CheckType(l:self)
  if maktaba#value#IsString(a:message)
    let l:message = [a:message]
  elseif maktaba#value#IsList(a:message)
    let l:message = a:message
  else
    throw maktaba#error#Failure(
        \ 'unfocus: Tried to debug log a non-string, non-list: %s',
        \ typevim#PrintShallow(a:message))
  endif
  let l:message = [s:GetTimestamp()] + l:message + ['']
  call l:self.buffer.InsertLines('$', l:message)
endfunction

""
" Open the debug log.
function! {s:prefix}Show() dict abort
  call s:CheckType(l:self)
  call l:self.buffer.Open()
endfunction
