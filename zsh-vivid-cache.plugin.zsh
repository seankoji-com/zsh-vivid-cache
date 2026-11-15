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
#   ZSH_VIVID_THEME       theme name or path, default 'snazzy'
#   ZSH_VIVID_CACHE_DIR   cache location, default ~/.cache/zsh
#
# Does nothing when vivid is not installed, leaving any LS_COLORS you already
# have alone.

: ${ZSH_VIVID_THEME:=snazzy}
: ${ZSH_VIVID_CACHE_DIR:=${HOME}/.cache/zsh}

# Encode separators so the filename uniquely identifies both inputs. Long
# keys use SHA-256 to stay within filesystem component length limits.
_vivid_cache_path() {
  local version digest key encoded='' byte i theme_key="$ZSH_VIVID_THEME"
  # Relative paths refer to different files when shells start in different directories.
  if [[ "$theme_key" != /* && ( "$theme_key" == */* || -f "$theme_key" ) ]]; then
    theme_key="$PWD/$theme_key"
  fi
  version="$(vivid --version 2>/dev/null)" || return 1
  [[ -n "$version" ]] || return 1
  local LC_ALL=C
  theme_key="${theme_key//\%/%25}"
  theme_key="${theme_key//\//%2F}"
  version="${version//\%/%25}"
  version="${version//\//%2F}"
  key="${theme_key}%00${version}"
  # Hex is safe on case-insensitive filesystems. Leave room for the temporary
  # filename on eCryptfs, whose component limit can be smaller than 255 bytes.
  if (( ${#key} <= 50 )); then
    for (( i = 1; i <= ${#key}; i++ )); do
      printf -v byte '%02x' "'${key[i]}"
      encoded+="$byte"
    done
    REPLY="${ZSH_VIVID_CACHE_DIR}/ls_colors.k.${encoded}"
    return 0
  fi
  if (( $+commands[sha256sum] )); then
    digest="$(printf '%s' "$key" | sha256sum)" || return 1
  elif (( $+commands[shasum] )); then
    digest="$(printf '%s' "$key" | shasum -a 256)" || return 1
  else
    print -u2 'vivid cache: sha256sum or shasum is required'
    return 1
  fi
  digest="${digest%% *}"
  [[ ${#digest} -eq 64 && "$digest" != *[^0-9a-f]* ]] || return 1
  REPLY="${ZSH_VIVID_CACHE_DIR}/ls_colors.h.${digest}"
}

vivid_cache_path() {
  local REPLY
  _vivid_cache_path || return 1
  print -r -- "$REPLY"
}

# Refresh after editing a custom theme file; its contents are not in the key.
vivid_cache_refresh() {
  (( $+commands[vivid] )) || {
    print -u2 "vivid_cache_refresh: vivid is not installed"
    return 1
  }
  local cache REPLY
  _vivid_cache_path || {
    print -u2 'vivid_cache_refresh: could not determine cache key'
    return 1
  }
  cache="$REPLY"
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
  local cache REPLY
  _vivid_cache_path || return 0
  cache="$REPLY"
  [[ -s "$cache" ]] || _vivid_cache_generate "$cache" || return 0
  export LS_COLORS="$(<$cache)"
}

vivid_cache_load
