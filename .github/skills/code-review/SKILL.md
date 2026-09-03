---
name: code-review
description: Review priorities for zsh-vivid-cache pull requests — what deserves real scrutiny versus what to skip. Use for every PR review.
---

# Review priorities

zsh-vivid-cache is one ~50-line zsh plugin (`zsh-vivid-cache.plugin.zsh`) whose
whole job is caching `vivid`'s `LS_COLORS` output. There's no recurring-bug
history to mine here — the four closed PRs on this repo are all CI/template
housekeeping, not fixes. The priorities below come from the code's own stated
invariants and its test suite, not from a bug pattern.

## Spend real attention here

- **The atomic-write invariant in `vivid_cache_refresh`**: write to `$cache.$$`,
  reject empty output (`[[ -s "$tmp" ]]`), only then `mv` into place, and
  `rm -f "$tmp"` on every failure exit. A regression here doesn't crash — it
  leaves a half-written cache every later shell trusts, so the symptom is
  subtly wrong file colours, never an error. The plugin's own comments and the
  spec file both call this out as the thing that matters most.
- **The absent/failing-`vivid` paths in `vivid_cache_load`**: must be a silent
  no-op when `vivid` isn't on `PATH`, and must leave a pre-existing
  `LS_COLORS` untouched when generation fails. Flag anything that makes either
  path noisy, fatal, or destructive to an `LS_COLORS` the user already had.
- **Cache-key scope**: the key is `$ZSH_VIVID_THEME` alone, by design —
  upgrading vivid or editing a custom theme does not auto-invalidate the
  cache; `vivid_cache_refresh` is the documented manual escape hatch. A change
  that alters what invalidates the cache needs the README and the plugin's
  header comment updated to match, not just the code.
- **Logic changes without a matching spec**: `spec/zsh-vivid-cache_spec.sh`
  drives every failure path through a `fake_vivid` stub (stdout + exit
  status). CI runs shellspec but never shellcheck, so this review is the only
  check on quoting/word-splitting/glob bugs in the `.zsh` — verify directly,
  don't assume a green check covers it.

## Do not spend attention here

- PRs titled `chore(ci): sync caller templates from seankoji-com/.github` —
  mechanical syncs pushed from the org hub. Confirm they only touch
  `.github/workflows/*.yml`; skip deep review of the synced content itself.
- `spec/spec_helper.sh` — fixed shellspec bootstrap boilerplate, no project
  logic.
- `.github/workflows/codeql.yml` scans workflow YAML for injection (there's no
  shell analyzer for the plugin itself) — don't expect it to catch shell bugs,
  and don't re-flag what it already covers in workflow files.
- README/LICENSE wording — no functional risk.

## Comment style

- One comment per real issue, not one per file it repeats in.
- Skip restating what the shellspec CI check already flags as failing.
- On workflow-file changes, flag real risk only — secrets or untrusted input
  reaching a `run:` step, or reintroducing a self-hosted runner for this
  public repo (see the guard comment in `shellspec.yml`) — not style.
