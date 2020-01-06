""
" Return 1 if {new_info} represents a different window than {old_info},
" and 0 otherwise.
"
" {new_info} and {old_info} must have `winid` and `bufnr` variables.
function! unfocus#focus#DifferentWindow(old_info, new_info) abort
  call typevim#ensure#IsType(a:old_info, 'WindowInfo')
  call typevim#ensure#IsType(a:new_info, 'WindowInfo')
  return a:old_info.winid !=# a:new_info.winid
endfunction

""
" Return 1 if {new_info} represents a different buffer than {old_info},
" and 0 otherwise.
"
" {new_info} and {old_info} must have `winid` and `bufnr` variables.
function! unfocus#focus#DifferentBuffer(old_info, new_info) abort
  call typevim#ensure#IsType(a:old_info, 'WindowInfo')
  call typevim#ensure#IsType(a:new_info, 'WindowInfo')
  return a:old_info.bufnr !=# a:new_info.bufnr
endfunction

""
" Return 1 if {new_info} represents a different window and buffer pair than
" {old_info}, and 0 otherwise.
"
" {new_info} and {old_info} must have `winid` and `bufnr` variables.
function! unfocus#focus#DifferentWindowOrBuffer(old_info, new_info) abort
  return a:old_info.bufnr !=# a:new_info.bufnr
      \ || a:old_info.winid !=# a:new_info.winid
endfunction
