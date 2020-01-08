let [s:plugin, s:___] = maktaba#plugin#Enter(expand('<sfile>:p'))

" we always want to source this script at least once, to register the autocmd
" enable/disable callbacks
if exists('s:did_enter')
  finish
endif
let s:did_enter = 1

let s:first_run = 1

""
" Toggle the unfocus_update augroup based on the value of @flag(plugin). Allow
" runtime loading/disdabling of the vim-unfocus autocmd groups.
function! s:EnableDisableAutocmds(plugin_flag) abort
  let l:enable_autocmds = get(a:plugin_flag, 'autocmds', 0)
  if l:enable_autocmds
    " Actions that fire whenever the active window changes.
    augroup unfocus_update
      au!
      autocmd VimEnter,BufEnter,BufWinEnter,WinEnter *
          \ call unfocus#SwitchFocusIfDifferent(
              \ win_getid(), unfocus#CurrentFocusSettings(win_getid()))

      autocmd WinLeave  * call unfocus#cleanup#MarkLeavingWindow(win_getid())
      autocmd WinEnter  * call unfocus#cleanup#CleanUpLeftWindowIfClosed()
      autocmd TabLeave  * call unfocus#cleanup#StoreLeftTabPage(tabpagenr())
      autocmd TabClosed * call unfocus#cleanup#CleanUpClosedTab(
                              \ unfocus#cleanup#LastLeftTabPage())
      autocmd WinNew    * call unfocus#cleanup#MarkNewWindowInTab(win_getid(), tabpagenr())
    augroup end

    if !s:first_run
      call unfocus#cleanup#GarbageCollect()
      call unfocus#AddUnseen()
    endif

  else  " disable autocmds
    augroup unfocus_update
      au!
    augroup end
    augroup! unfocus_update

    if !s:first_run
      call unfocus#cleanup#GarbageCollect()
    endif

  endif
endfunction
call s:plugin.flags.plugin.AddCallback(function('s:EnableDisableAutocmds'))

let s:first_run = 0
