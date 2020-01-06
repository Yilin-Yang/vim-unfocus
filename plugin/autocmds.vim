let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif


function! s:EnableDisableAutocmds(plugin_flag) abort
  let l:enable_autocmds = get(a:plugin_flag, 'autocmds', 1)
  if l:enable_autocmds
    " Actions that fire whenever the active window changes.
    augroup unfocus_update
      au!
      " TODO VimEnter
      autocmd VimEnter,BufEnter,BufWinEnter,WinEnter *
          \ call unfocus#SwitchFocusIfDifferent(win_getid())
    augroup end
  else  " disable autocmds
    augroup unfocus_update
      au!
    augroup end
    augroup! unfocus_update
  endif
endfunction

call s:plugin.flags.plugin.AddCallback(function('s:EnableDisableAutocmds'))
