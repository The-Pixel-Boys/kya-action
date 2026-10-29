# Releasing kya-action

This page sets the release and tag policy for this action. Users pin it, so a
release must never change under them.

## Policy

1. **Releases are immutable.** A release tag names one commit. Once published,
   the tag and the release never move or change. Enable the repository setting
   "Immutable releases" so GitHub enforces this.
2. **Version tags** use `vMAJOR.MINOR.PATCH`, for example `v1.1.0`.
3. **Floating major tag `v1`.** It moves only for compatible fixes. A move is
   allowed when no input or output is removed or renamed, no default changes
   the pass or fail result, and no new input is required. A new optional input
   with a default (such as `footer`) is compatible, so it ships in `v1.x`.
   Move `v1` only after the matching `v1.x.y` release is published.
4. **Pin by commit SHA.** Users should pin this action to a full commit SHA with
   a version comment. The README shows how.
5. **Pin third-party steps.** Every third-party step in this repo's workflows and
   in `action.yml` uses a full commit SHA with a `# vX.Y.Z` comment.

## Why

In March 2026 the tags on `trivy-action` were compromised. Workflows pinned to a
tag ran the malicious code, and workflows pinned to a commit SHA did not. This
policy removes both gaps: our own steps and our users' steps pin to SHAs, and
published releases cannot change.

## Status for v1.1.0 (candidate)

- v1.1.0 is a candidate only. No tag and no release exist for it.
- It is on the branch `agent/action/v1-1` until its pull request is merged.
- Current state of the older releases: `v1.0.3` and `v1.0.2` report
  `immutable: false` (checked with `gh api repos/The-Pixel-Boys/kya-action/releases`).
- `v1` points at `b622b8d`, which is `v1.0.3`. Commit `3dc4673` is on `main`
  but not in any release yet. It refuses symlinked report paths, so v1.1.0 is
  the first release that includes it.

## Owner steps (not done by the agent)

- [ ] Enable "Immutable releases" in the repository settings.
- [ ] Review and merge the v1.1.0 pull request. Wait for green checks on `main`.
- [ ] Create tag `v1.1.0` on the merge commit and publish the release (owner go).
- [ ] After the release is published, move the floating `v1` tag to the same
      commit, and say so in the release notes.
- [ ] Paste the Marketplace listing text from the pull request into the listing.

## Verify a release

```sh
gh api repos/The-Pixel-Boys/kya-action/commits/v1.1.0 --jq .sha
gh api repos/The-Pixel-Boys/kya-action/releases/tags/v1.1.0 --jq '{tag_name, immutable, draft}'
```
