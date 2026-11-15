# zsh-vivid-cache

Caches [vivid](https://github.com/sharkdp/vivid)'s `LS_COLORS` instead of
regenerating it on every shell start.

The plugin runs `vivid --version` to select a cache on each load. It runs
`vivid generate` only when that cache is missing or you refresh it.

## Install

```sh
git clone https://github.com/seankoji-com/zsh-vivid-cache \
  ~/.oh-my-zsh_custom/plugins/zsh-vivid-cache
```

```zsh
plugins=(... zsh-vivid-cache)
```

## Configure

Set before the plugin loads.

| Variable | Default | Meaning |
|---|---|---|
| `ZSH_VIVID_THEME` | `snazzy` | Theme name or custom theme path. `vivid themes` lists bundled names |
| `ZSH_VIVID_CACHE_DIR` | `~/.cache/zsh` | Where the cache lives |

The cache key includes the full theme argument and the output of `vivid --version`.
Relative theme paths also include the shell's current directory.
Switching themes or upgrading vivid generates a new cache. Extremely long keys
that would exceed the path length budget require a SHA-256 utility (`sha256sum`
or `shasum`).

Old cache files remain when themes or vivid versions change, including files
created by older plugin versions. No cache files are deleted automatically.
Use a dedicated `ZSH_VIVID_CACHE_DIR` if you want to inspect and remove its
contents manually; check the directory before removing anything.

Does nothing when vivid is not installed, leaving any `LS_COLORS` you already
have alone.

## Refreshing

Editing a custom theme, whether selected by name or path, does not change the
cache key. Refresh the cache after editing it:

```zsh
vivid_cache_refresh
```

`vivid_cache_path` prints the current cache file path for inspection. It also
checks the installed vivid version.

Generation writes to a temporary file and moves it into place. A failed or
truncated run would otherwise leave a half-written cache that every later shell
trusts, and the symptom is subtly wrong file colours rather than an error.

## Licence

MIT
