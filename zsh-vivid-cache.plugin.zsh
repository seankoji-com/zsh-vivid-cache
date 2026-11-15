# zsh-vivid-cache — cache vivid's LS_COLORS instead of regenerating it.
#
# vivid (https://github.com/sharkdp/vivid) generates a good LS_COLORS from a
# named theme, but it is a subprocess, and running it on every shell start to
# produce a string that only changes when you change themes is waste. This
# generates once and reads a cache file thereafter.
#
# The cache is keyed by the complete theme argument and vivid version.
#
# Configure before loading:
#   ZSH_VIVID_THEME       theme name, default 'snazzy'. `vivid themes` lists them
#   ZSH_VIVID_CACHE_DIR   cache location, default ~/.cache/zsh
#
# Does nothing when vivid is not installed, leaving any LS_COLORS you already
# have alone.

: ${ZSH_VIVID_THEME:=snazzy}
: ${ZSH_VIVID_CACHE_DIR:=${HOME}/.cache/zsh}

# Separate the inputs with NUL before hashing to keep paths safe and distinct.
vivid_cache_path() {
  local version digest theme_key="$ZSH_VIVID_THEME"
  # Relative paths refer to different files when shells start in different directories.
  if [[ "$theme_key" == */* && "$theme_key" != /* ]]; then
    theme_key="$PWD/$theme_key"
  fi
  version="$(vivid --version 2>/dev/null)" || return 1
  [[ -n "$version" ]] || return 1
  if (( $+commands[sha256sum] )); then
    digest="$(printf '%s\0%s' "$theme_key" "$version" | sha256sum)" || return 1
  elif (( $+commands[shasum] )); then
    digest="$(printf '%s\0%s' "$theme_key" "$version" | shasum -a 256)" || return 1
  else
    print -u2 'vivid cache: sha256sum or shasum is required'
    return 1
  fi
  digest="${digest%% *}"
  [[ ${#digest} -eq 64 && "$digest" != *[^0-9a-f]* ]] || return 1
  print -r -- "${ZSH_VIVID_CACHE_DIR}/ls_colors.${digest}"
}

# Refresh after editing a custom theme file; its contents are not in the key.
vivid_cache_refresh() {
  (( $+commands[vivid] )) || {
    print -u2 "vivid_cache_refresh: vivid is not installed"
    return 1
  }
  local cache
  cache="$(vivid_cache_path)" || return 1
  _vivid_cache_generate "$cache"
}

_vivid_cache_generate() {
  local cache="$1"
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
  local cache
  cache="$(vivid_cache_path)" || return 0
  [[ -s "$cache" ]] || _vivid_cache_generate "$cache" || return 0
  export LS_COLORS="$(<$cache)"
}

vivid_cache_load
