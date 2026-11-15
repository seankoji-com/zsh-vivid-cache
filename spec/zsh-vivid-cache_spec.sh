# shellcheck shell=bash disable=all
Describe 'zsh-vivid-cache.plugin.zsh'
  # Neutralise PATH before Include. The plugin calls vivid_cache_load at the
  # bottom, and a real vivid on PATH would write to the developer's actual
  # ~/.cache/zsh while the suite runs.
  REAL_PATH="$PATH"
  PATH="/usr/bin:/bin"

  setup() {
    TMPROOT="$(mktemp -d)"
    ZSH_VIVID_CACHE_DIR="$TMPROOT/cache"
    ZSH_VIVID_THEME=testtheme
    FAKEBIN="$TMPROOT/bin"
    mkdir -p "$FAKEBIN"
    PATH="$FAKEBIN:/usr/bin:/bin"
    hash -r
  }
  cleanup() { rm -rf "$TMPROOT"; }
  BeforeEach 'setup'
  AfterEach 'cleanup'

  fake_vivid() {
    # $1 stdout, $2 exit status
    cat > "$FAKEBIN/vivid" <<EOF
#!/bin/sh
if [ "\$1" = --version ]; then
  printf '%s\n' "\${FAKE_VIVID_VERSION:-vivid 1}"
  exit 0
fi
printf '%s' "$1"
exit ${2:-0}
EOF
    chmod +x "$FAKEBIN/vivid"
    hash -r
  }

  no_vivid() { rm -f "$FAKEBIN/vivid"; hash -r; }

  Include ./zsh-vivid-cache.plugin.zsh

  Describe 'vivid_cache_refresh'
    It 'writes the cache for the current theme and version'
      run_it() {
        fake_vivid 'di=01;34:'
        vivid_cache_refresh
        cat "$(vivid_cache_path)"
      }
      When call run_it
      The output should equal 'di=01;34:'
    End

    It 'creates the cache directory'
      run_it() { fake_vivid 'x'; vivid_cache_refresh; [[ -d "$ZSH_VIVID_CACHE_DIR" ]] && print MADE; }
      When call run_it
      The output should equal 'MADE'
    End

    # A truncated cache would be trusted by every later shell, and the symptom
    # is subtly wrong file colours rather than an error.
    It 'leaves no cache behind when vivid fails'
      run_it() {
        fake_vivid 'partial' 1
        vivid_cache_refresh 2>/dev/null
        [[ -f "$(vivid_cache_path)" ]] && print PRESENT || print ABSENT
      }
      When call run_it
      The output should equal 'ABSENT'
    End

    It 'reports a failing vivid'
      run_it() { fake_vivid '' 1; vivid_cache_refresh; }
      When call run_it
      The status should be failure
      The stderr should include 'failed'
    End

    It 'rejects empty output'
      run_it() { fake_vivid '' 0; vivid_cache_refresh; }
      When call run_it
      The status should be failure
      The stderr should include 'produced nothing'
    End

    It 'errors when vivid is not installed'
      run_it() { no_vivid; vivid_cache_refresh; }
      When call run_it
      The status should be failure
      The stderr should include 'not installed'
    End

    It 'explains when the version cannot be read'
      run_it() {
        cat > "$FAKEBIN/vivid" <<'EOF'
#!/bin/sh
exit 1
EOF
        chmod +x "$FAKEBIN/vivid"
        hash -r
        vivid_cache_refresh
      }
      When call run_it
      The status should be failure
      The stderr should include 'could not determine cache key'
    End
  End

  Describe 'vivid_cache_load'
    It 'generates on a cold cache and exports LS_COLORS'
      run_it() { fake_vivid 'di=01;34:'; vivid_cache_load; print -r -- "$LS_COLORS"; }
      When call run_it
      The output should equal 'di=01;34:'
    End

    It 'reads the cache without running vivid again'
      run_it() {
        fake_vivid 'first'
        vivid_cache_load
        fake_vivid 'second'
        unset LS_COLORS
        vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'first'
    End

    # Switching themes has to invalidate itself without manual intervention.
    It 'regenerates when the theme name changes'
      run_it() {
        fake_vivid 'theme-a-colors'
        vivid_cache_load
        ZSH_VIVID_THEME=othertheme
        fake_vivid 'theme-b-colors'
        unset LS_COLORS
        vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'theme-b-colors'
    End

    It 'keeps path themes with the same basename distinct and reuses each cache'
      run_it() {
        fake_vivid 'first'
        ZSH_VIVID_THEME='/one/theme.yaml'; vivid_cache_load
        fake_vivid 'second'
        ZSH_VIVID_THEME='/two/theme.yaml'; vivid_cache_load
        print -r -- "$LS_COLORS"
        ZSH_VIVID_THEME='/one/theme.yaml'; vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The line 1 of output should equal 'second'
      The line 2 of output should equal 'first'
    End

    It 'keeps escaped separators distinct from literal percent sequences'
      run_it() {
        fake_vivid 'first'
        ZSH_VIVID_THEME='/one/theme.yaml'; vivid_cache_load
        fake_vivid 'second'
        ZSH_VIVID_THEME='/one%2Ftheme.yaml'; vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'second'
    End

    It 'keeps names distinct on a case-insensitive filesystem'
      run_it() {
        fake_vivid 'colors'
        ZSH_VIVID_THEME='Theme'; local first="$(vivid_cache_path)"
        ZSH_VIVID_THEME='theme'; local second="$(vivid_cache_path)"
        [[ "${(L)first}" != "${(L)second}" ]] && print DISTINCT
      }
      When call run_it
      The output should equal 'DISTINCT'
    End

    It 'uses a fixed-length key for long theme paths'
      run_it() {
        fake_vivid 'first'
        ZSH_VIVID_THEME="/${(l:300::a:)}"; vivid_cache_load
        fake_vivid 'second'
        ZSH_VIVID_THEME="/${(l:300::b:)}"; vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'second'
    End

    It 'does not need a hash command for short keys'
      run_it() {
        fake_vivid 'colors'
        cat > "$FAKEBIN/sha256sum" <<'EOF'
#!/bin/sh
exit 1
EOF
        chmod +x "$FAKEBIN/sha256sum"
        hash -r
        vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'colors'
    End

    It 'preserves the caller REPLY variable'
      run_it() {
        fake_vivid 'colors'
        REPLY='caller value'
        vivid_cache_load
        print -r -- "$REPLY"
      }
      When call run_it
      The output should equal 'caller value'
    End

    It 'leaves LS_COLORS alone if hashing a long key fails'
      run_it() {
        fake_vivid 'colors'
        cat > "$FAKEBIN/sha256sum" <<'EOF'
#!/bin/sh
exit 1
EOF
        chmod +x "$FAKEBIN/sha256sum"
        hash -r
        ZSH_VIVID_THEME="/${(l:120::a:)}"
        LS_COLORS='preexisting'
        vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'preexisting'
    End

    It 'regenerates when vivid version changes'
      run_it() {
        export FAKE_VIVID_VERSION='vivid 1'
        fake_vivid 'first'; vivid_cache_load
        FAKE_VIVID_VERSION='vivid 2'
        fake_vivid 'second'; vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'second'
    End

    It 'distinguishes the same relative path in different directories'
      run_it() {
        mkdir -p "$TMPROOT/one" "$TMPROOT/two"
        ZSH_VIVID_THEME='./theme.yaml'
        cd "$TMPROOT/one" || return
        fake_vivid 'first'; vivid_cache_load
        cd "$TMPROOT/two" || return
        fake_vivid 'second'; vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'second'
    End

    It 'distinguishes bare theme files in different directories'
      run_it() {
        mkdir -p "$TMPROOT/one" "$TMPROOT/two"
        touch "$TMPROOT/one/theme.yaml" "$TMPROOT/two/theme.yaml"
        ZSH_VIVID_THEME='theme.yaml'
        cd "$TMPROOT/one" || return
        fake_vivid 'first'; vivid_cache_load
        cd "$TMPROOT/two" || return
        fake_vivid 'second'; vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'second'
    End

    It 'is a no-op when vivid is missing'
      run_it() {
        no_vivid
        LS_COLORS='preexisting'
        vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'preexisting'
      The status should be success
    End

    It 'leaves LS_COLORS alone when generation fails'
      run_it() {
        fake_vivid '' 1
        LS_COLORS='preexisting'
        vivid_cache_load 2>/dev/null
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'preexisting'
      The status should be success
    End

    It 'leaves LS_COLORS alone when the version cannot be read'
      run_it() {
        cat > "$FAKEBIN/vivid" <<'EOF'
#!/bin/sh
exit 1
EOF
        chmod +x "$FAKEBIN/vivid"
        LS_COLORS='preexisting'
        vivid_cache_load
        print -r -- "$LS_COLORS"
      }
      When call run_it
      The output should equal 'preexisting'
      The status should be success
    End
  End
  Describe 'refreshing a working cache'
    Parameters
      partial 1
      '' 0
    End
    It 'preserves the previous cache and removes failed temporary output'
      run_it() {
        fake_vivid 'known-good'
        vivid_cache_refresh || return
        fake_vivid "$1" "$2"
        vivid_cache_refresh 2>/dev/null
        local rc=$?
        local cache="$(vivid_cache_path)"
        print -r -- "$(<$cache)"
        local -a leftovers
        leftovers=("$cache".*(N))
        print -r -- "${#leftovers}"
        return $rc
      }
      When call run_it "$1" "$2"
      The status should be failure
      The line 1 of output should equal 'known-good'
      The line 2 of output should equal '0'
    End
  End

End
