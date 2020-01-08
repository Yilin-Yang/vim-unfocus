let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" Globals used for maintaining a global plugin state.

let s:unfocus_focus_settings_map =
    \ unfocus#FocusSettingsMap#New(
        \ s:plugin.flags.to_set, function('unfocus#InitializeFocused'))

""
" @private
" Retrieve the datastructure that vim-unfocus uses to map between |winid|s and
" @dict(FocusSettings) objects.
function! UnfocusGetFocusSettingsMap() abort
  return s:unfocus_focus_settings_map
endfunction
