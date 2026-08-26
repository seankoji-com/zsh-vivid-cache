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
printf '%s' "$1"
exit ${2:-0}
EOF
    chmod +x "$FAKEBIN/vivid"
    hash -r
  }

  no_vivid() { rm -f "$FAKEBIN/vivid"; hash -r; }

  Include ./zsh-vivid-cache.plugin.zsh

  Describe 'vivid_cache_refresh'
    It 'writes the cache keyed by theme name'
      run_it() {
        fake_vivid 'di=01;34:'
        vivid_cache_refresh
        cat "$ZSH_VIVID_CACHE_DIR/ls_colors.testtheme"
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
        [[ -f "$ZSH_VIVID_CACHE_DIR/ls_colors.testtheme" ]] && print PRESENT || print ABSENT
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
  End
End
