let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" Globals used for maintaining a global plugin state.

let s:map_per_window = v:null
let s:map_per_window_and_buffer = v:null
let s:map_per_buffer = v:null


""
" @private
" Retrieve the datastructure that vim-unfocus uses to map between |winid|s and
" @dict(FocusSettings) objects.
function! UnfocusGetFocusSettingsMap() abort
  return s:unfocus_focus_settings_map
endfunction
let s:unfocus_focus_settings_map = v:null



""
" Register a callback that fires on changes to @flag(store_settings_per),
" changing the focus_settings_map singleton.
function! s:ChangeFocusSettingsMap(store_settings_per) abort
  if a:store_settings_per ==# 'window'
    if s:map_per_window is v:null
      let s:map_per_window =
          \ unfocus#WindowFocusSettingsMap#New(s:f_TO_SET, s:INITIALIZE_FOCUSED)
    endif
    let s:unfocus_focus_settings_map = s:map_per_window
  " elseif a:store_settings_per ==# 'window_and_buffer'
  " elseif a:store_settings_per ==# 'buffer'
  else
    throw maktaba#error#Failure(
        \ 'unknown store_settings_per value: %s', a:store_settings_per)
  endif
endfunction
let s:f_TO_SET = s:plugin.flags.to_set
let s:INITIALIZE_FOCUSED = function('unfocus#InitializeFocused')

call s:plugin.flags.store_settings_per.AddCallback(
    \ function('s:ChangeFocusSettingsMap'))
