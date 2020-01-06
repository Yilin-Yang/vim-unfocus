let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" Globals used for maintaining a global plugin state.

let s:map_per_window = v:null
let s:map_per_window_and_buffer = v:null
let s:map_per_buffer = v:null

let g:unfocus_focus_settings_map = v:null


let s:INITIALIZE_FOCUSED = function('unfocus#InitializeFocused')

""
" Register a callback that fires on changes to @flag(store_settings_per),
" changing the global v_focus_settings_map.
function! s:ChangeFocusSettingsMap(store_settings_per) abort
  if a:store_settings_per ==# 'window'
    if s:map_per_window is v:null
      let s:map_per_window =
          \ unfocus#FocusSettingsMap#New(s:f_TO_SET, s:INITIALIZE_FOCUSED)
    endif
    let g:unfocus_focus_settings_map = s:map_per_window
  " elseif a:store_settings_per ==# 'window_and_buffer'
  " elseif a:store_settings_per ==# 'buffer'
  else
    throw maktaba#error#Failure(
        \ 'unknown store_settings_per value: %s', a:store_settings_per)
  endif
endfunction
let s:f_TO_SET = s:plugin.flags.to_set
call s:plugin.flags.store_settings_per.AddCallback(
    \ function('s:ChangeFocusSettingsMap'))


""
" The @dict(FocusSettings) and @dict(WindowInfo) for the most recently focused
" window in a dictionary.
let g:unfocus_last_focused = {'focus_settings': 0, 'window_info': 0}
