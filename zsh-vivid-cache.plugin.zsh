# zsh-vivid-cache — cache vivid's LS_COLORS instead of regenerating it.
#
# vivid (https://github.com/sharkdp/vivid) generates a good LS_COLORS from a
# named theme, but it is a subprocess, and running it on every shell start to
# produce a string that only changes when you change themes is waste. This
# generates once and reads a cache file thereafter.
#
# The cache is keyed by theme name, so switching themes regenerates itself
# with no manual invalidation.
#
# Configure before loading:
#   ZSH_VIVID_THEME       theme name, default 'snazzy'. `vivid themes` lists them
#   ZSH_VIVID_CACHE_DIR   cache location, default ~/.cache/zsh
#
# Does nothing when vivid is not installed, leaving any LS_COLORS you already
# have alone.

: ${ZSH_VIVID_THEME:=snazzy}
: ${ZSH_VIVID_CACHE_DIR:=${HOME}/.cache/zsh}

# Regenerate the cache for the current theme. Call after upgrading vivid, or
# after editing a custom theme file, since neither changes the theme name.
vivid_cache_refresh() {
  (( $+commands[vivid] )) || {
    print -u2 "vivid_cache_refresh: vivid is not installed"
    return 1
  }
  local cache="${ZSH_VIVID_CACHE_DIR}/ls_colors.${ZSH_VIVID_THEME}"
  mkdir -p "${cache:h}" || return 1

  # Generate to a temporary file and move it into place. A failed or truncated
  # run would otherwise leave a half-written cache that every later shell
  # trusts, and the symptom (subtly wrong file colours) is not one you would
  # trace back to here.
  local tmp="${cache}.$$"
  if ! vivid generate "$ZSH_VIVID_THEME" > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    print -u2 "vivid_cache_refresh: vivid generate '$ZSH_VIVID_THEME' failed"
    return 1
  fi
  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    print -u2 "vivid_cache_refresh: vivid generate '$ZSH_VIVID_THEME' produced nothing"
    return 1
  fi
  mv "$tmp" "$cache"
}

vivid_cache_load() {
  (( $+commands[vivid] )) || return 0
  local cache="${ZSH_VIVID_CACHE_DIR}/ls_colors.${ZSH_VIVID_THEME}"
  [[ -s "$cache" ]] || vivid_cache_refresh || return 0
  export LS_COLORS="$(<$cache)"
}

vivid_cache_load
