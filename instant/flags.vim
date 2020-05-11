let [s:plugin, s:enter] = maktaba#plugin#Enter(expand('<sfile>:p'))
if !s:enter
  finish
endif

""
" @section Configuration, config
" vim-unfocus may be configured in one of two ways: by using Google's Glaive
" plugin; or by setting vim-unfocus's maktaba flags manually. Note that Glaive
" is essentially a wrapper around the latter option with simpler syntax;
" functionally, the two are the same.
"
" Install Glaive (https://github.com/google/glaive) to use the |:Glaive|
" command to configure dapper.nvim's maktaba flags. Configuring vim-unfocus's
" settings in your .vimrc can look like:
" >
"   " with Glaive,
"   Glaive vim-unfocus on_new_window='inherit_from_current'
"
"   " with direct manipulation of maktaba flags,
"   let g:vim_unfocus = maktaba#plugin#Get('vim-unfocus')
"   call g:vim_unfocus.Flag('on_new_window', 'inherit_from_current')
" <
"
" Both Glaive and explicit flag manipulation can also be used from the
" command line during an editing session: see |:Glaive| and |Plugin.Flag()| for
" details.


"
" Helpers
"


""
" Returns a wrapper function around maktaba#ensure#IsIn that takes a single
" argument and checks whether it can be found in {values}.
"
" @throws WrongType if {values} is not a list.
function! s:EnsureIsIn(values) abort
  call maktaba#ensure#IsList(a:values)
  return {value -> maktaba#ensure#IsIn(value, a:values)}
endfunction

""
" Returns a callable function that iterates over a list of items and passes
" each element into {Predicate}.
function! s:EnsureThatAll(Predicate) abort
  call maktaba#ensure#IsCallable(a:Predicate)
  return {items -> map(items, {_, Item -> a:Predicate(Item)})}
endfunction


"
" Flags
"


" (private)
" A list of all settings provided in @flag(to_set). Repopulated whenever
" @flag(to_set) changes.
call s:plugin.Flag('watched_settings', [])
call s:plugin.flags.watched_settings.AddTranslator(
    \ function('maktaba#ensure#IsList'))

""
" Pull all keys from "on_focus" and "on_unfocus" in @flag(to_set) and use them
" to set @flag(watched_settings).
function! s:UpdatedWatchedSettings(to_set)
  let l:on_focus = get(a:to_set, 'on_focus', {})
  let l:on_unfocus = get(a:to_set, 'on_unfocus', {})

  let l:settings_dict = copy(l:on_focus)
  call extend(l:settings_dict, l:on_unfocus, 'keep')

  " sort the keys to make testing easier and to make errors related to option
  " setting more reproducable
  " we don't expect this function to be called often, so the performance
  " impact should be negligible
  let l:settings = sort(keys(l:settings_dict))

  call s:plugin.Flag('watched_settings', l:settings)
endfunction


""
" Verify that @flag(to_set) is a dict, then add default on_focus, on_unfocus
function! s:InitializeToSet(to_set) abort
  call maktaba#ensure#IsDict(a:to_set)
  call extend(a:to_set, {'on_focus': {}, 'on_unfocus': {}}, 'keep')
  if !maktaba#value#IsDict(a:to_set.on_focus)
      \ || !maktaba#value#IsDict(a:to_set.on_unfocus)
    throw maktaba#error#BadValue(
        \ 'on_focus and on_unfocus must be dicts, gave: %s, %s',
        \ string(a:to_set.on_focus), string(a:to_set.on_unfocus))
  endif
  return a:to_set
endfunction


""
" Window-local settings and variable values to be set when focusing or
" unfocusing a window.
"
" This flag should be a dict with (up to) two keys: "on_focus", and
" "on_unfocus".  The associated values should be dicts between settings (which
" should be legal {varname}s in calls to |gettabwinvar()|, e.g.
" "&relativenumber") and their desired value. In principle, any string that
" can be passed to |gettabwinvar()| can be used as a "setting", but using
" anything other than window-local settings or window-scoped variables may
" result in unexpected behavior.
"
" Settings in "on_focus" are called "focus settings" and and settings in
" "on_unfocus" are called "unfocus settings". Either or both can be omitted.
" Focus settings and unfocus settings, combined, are called "watched
" settings".
"
" A window is "focused" when it is the current, active window. All other
" windows are "unfocused". To focus a window is to enter/"switch to" the
" window; to unfocus a window is to leave the window, such as by opening a new
" split or by switching tabs.
"
" Each window keeps two settings dicts: settings to be set when focused, and
" to be set when unfocused. These are usually initialized the user's focus
" settings and unfocus settings.
"
" When focusing an unfocused window, the current values of all of the watched
" settings for that window are stashed as that window's unfocused settings,
" and the settings in its focused settings dict are applied, and vice versa
" when unfocusing a focused window.
"
" If the user changes a watched setting for an unfocused window (e.g. through
" a call to |settabwinvar()|), then that value will be stashed into the
" unfocused settings dict when the window is next focused. Similarly, if the
" user changes the value of a watched setting while the window is focused
" (e.g. through a call to `:set {option}`), that value will be stashed into
" the focused settings dict when the window is unfocused. This prevents
" vim-unfocus from clobbering window variables that the user changes on
" purpose.
"
call s:plugin.Flag('to_set', {'on_focus': {}, 'on_unfocus': {}})
call s:plugin.flags.to_set.AddTranslator(function('s:InitializeToSet'))
call s:plugin.flags.to_set.AddCallback(function('s:UpdatedWatchedSettings'))


""
" How to initialize watched window settings when opening an entirely new window
" (i.e. one that vim-unfocus had not previously been tracking).
"
" Possible values are:
"
" - inherit_from_current: The current values of the watched window settings in
"   the current window are carried over and used as the "focused" setting
"   values in the new window. This mimics vim's default behavior.
"
" - use_focused_settings: The "focused" setting values from @flag(to_set) are
"   applied on entering the new window.
"
call s:plugin.Flag('on_new_window', 'inherit_from_current')
call s:plugin.flags.on_new_window.AddTranslator(
    \ s:EnsureIsIn(['inherit_from_current', 'use_focused_settings']))


function! s:IsIgnoredBufType(winid) abort
  return maktaba#value#IsIn(
      \ unfocus#WinVarFromID(a:winid, '&buftype'),
      \ ['nofile', 'quickfix', 'help'])
endfunction

function! s:IsIgnoredBufHidden(winid) abort
  return maktaba#value#IsIn(
      \ unfocus#WinVarFromID(a:winid, '&bufhidden'),
      \ ['unload', 'delete', 'wipe'])
endfunction

""
" A list of callables; if any of these return a truthy value when given a
" window's |winid| as a user switches between windows, then that window will
" be ignored.
"
" If a window is ignored, switching to it will not unfocus the previous
" window. An unfocus/focus may only occur when the user switches back to a
" non-ignored window.
"
" By default, this list contains one function that ignores windows with the
" |buftype| "nofile", "quickfix", or "help"; or windows with a |bufhidden|
" setting of "unload", "delete", or "wipe". This is meant to prevent
" vim-unfocus from triggering on netrw windows, location lists, or scratch
" buffers, among other things.
"
" When writing functions to include in this list,
" @function(unfocus#WinVarFromID) may be helpful for querying information
" about a particular window.
"
" Appending callables to this flag may be finicky, since (outside of calls to
" |Flag.Set()|) maktaba flags are meant to be immutable. See |Flag.Get()| and
" |Flag.GetCopy()|; the latter function should be helpful for this purpose.
"
" For instance, to add a function to ignore windows where `w:some_var` is 1,
" one could add the following to their |vimrc|:
" >
"   let g:unfocus = maktaba#plugin#Get('vim-unfocus')
"   function! IgnoreSomeVar1(winid) abort
"     return unfocus#WinVarFromID(a:winid)
"   endfunction
"   call g:unfocus.flags.ignore_if.Set(
"       \ add(g:unfocus.flags.ignore_if.GetCopy(),
"           \ function('IgnoreSomeVar1')))
" <
"
call s:plugin.Flag('ignore_if', [
    \ function('s:IsIgnoredBufType'),
    \ function('s:IsIgnoredBufHidden'),
    \ ])
" ensure that ignore_if contains only funcrefs
call s:plugin.flags.ignore_if.AddTranslator(
    \ s:EnsureThatAll(function('maktaba#ensure#IsFuncref')))



function! s:EnableLoggingOnlyIfSupported(new_val) abort
  if !has('nvim') && !has('patch-8.1.0037')
    throw maktaba#error#NotImplemented(
        \ 'Cannot enable debug logging without nvim or patch 8.1.0037!')
  endif
  return a:new_val
endfunction

""
" Whether to enable debug logging. When set to 1 or |v:true|, logging messages
" will be added to the vim-unfocus debug log, which can be opened with
" @function(unfocus#OpenLog).
"
" Debug logging requires nvim, or a version of vim with patch 8.1.0037.
" If these conditions aren't met, it will not be possible to change this flag.
"
call s:plugin.Flag('enable_debug_logging', 0)
call s:plugin.flags.enable_debug_logging.AddTranslator(
    \ function('s:EnableLoggingOnlyIfSupported'))


"
" plugin[] flags
"
" keep this at the bottom, to place it alongside the other autogenerated
" plugin[] flag docs


""
" When set to zero, disables vim-unfocus's autocommands; this essentially
" "deactivates" the plugin. Set to 1 to reenable.
"
" This value can be modified at runtime (i.e. outside of the .vimrc) and will
" still behave as expected.
"
call s:plugin.Flag('plugin[autocmds]', 1)


""
" When set to zero, disables most (if not all) of vim-unfocus's persistent,
" stateful variables. It should be fine to leave this enabled while disabling
" `plugin[autocmds]`, but disabling this flag is safest when trying to
" completely disable vim-unfocus at runtime.
"
call s:plugin.Flag('plugin[state]', 1)
