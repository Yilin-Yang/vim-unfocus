let [s:plugin, s:___] = maktaba#plugin#Enter(expand('<sfile>:p'))

" we always want to source this script at least once, to register the autocmd
" enable/disable callbacks
if exists('s:did_enter')
  finish
endif
let s:did_enter = 1

""
" Toggle the unfocus_update augroup based on the value of @flag(plugin). Allow
" runtime loading/disdabling of the vim-unfocus autocmd groups.
function! s:EnableDisableAutocmds(plugin_flag) abort
  let l:enable_autocmds = get(a:plugin_flag, 'autocmds', 1)
  if l:enable_autocmds
    " Actions that fire whenever the active window changes.
    augroup unfocus_update
      au!
      autocmd VimEnter,BufEnter,BufWinEnter,WinEnter *
          \ call unfocus#SwitchFocusIfDifferent(
              \ win_getid(), unfocus#CurrentFocusSettings(win_getid()))
    augroup end
  else  " disable autocmds
    augroup unfocus_update
      au!
    augroup end
    augroup! unfocus_update
  endif
endfunction
call s:plugin.flags.plugin.AddCallback(function('s:EnableDisableAutocmds'))
