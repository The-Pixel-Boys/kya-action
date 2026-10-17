# KYA Certify GitHub Action

AI agent audit trail and trust baseline, in your CI.

[![Marketplace](https://img.shields.io/badge/marketplace-KYA%20Certify-purple)](https://github.com/marketplace/actions/kya-certify)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![npm @shield-agent/kya](https://img.shields.io/npm/v/@shield-agent/kya)](https://www.npmjs.com/package/@shield-agent/kya)

![KYA demo](docs/assets/kya-demo.gif)

`kya certify` checks your repo's local agent-activity evidence against the KYA Agent Trust Baseline and reports gaps. This action runs it in CI on any repository that uses AI coding agents and posts the gap summary as a PR comment.

## Quickstart

```yaml
name: KYA Certify
on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read
  pull-requests: write

jobs:
  certify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: The-Pixel-Boys/kya-action@v1
        with:
          fail-on: gap        # gap | never
          window-days: 30     # look-back window for agent-activity evidence
          comment-on-pr: true
```

## What you get

A PR comment with the certify status pill, pass/gap counts from the report's overall summary, trail event stats, and the top 5 gaps sorted by severity, each with its evidence hint.

Reports (JSON/MD/HTML) are written to `.kya/certify/` so you can upload them as workflow artifacts. When `fail-on: never`, the step never fails the job (also when the status is `error`) and the exit code is still exposed via the outputs and the PR comment.

To upload the reports, give the action step an `id` and skip the upload when the status is `error`, so a symlink planted under `.kya` in a PR is never followed into the artifact:

```yaml
      - uses: The-Pixel-Boys/kya-action@v1
        id: kya
      - uses: actions/upload-artifact@v4
        if: ${{ always() && steps.kya.outputs.status != 'error' }}
        with:
          name: kya-certify-report
          path: .kya/certify/
```

## Symlinks in the checkout

A pull request can commit symlinks. If `.kya`, `.kya/certify` or `.kya/certify/report.json` is a symlink or resolves outside the workspace, or anything under `.kya` is a symlink, the action does not run `kya certify` (or, if the link shows up during the run, does not read the report), reports `status=error` and posts no report contents in the PR comment. Newer kya releases also refuse such writes themselves: they exit 1 and print `PROJECT_PATH_REFUSED`. The action reports that as `status=error` too, never as `gap`. To fix it, replace the link with a regular directory or file and re-run.

Inputs are passed to the shell and to the comment script through environment variables, never by interpolating them into the script, so a workflow can feed them from PR data without opening a script injection.

## Requirements

The action installs Node.js 24 with `actions/setup-node` and then `@shield-agent/kya` from npm (`npm i -g`). The CLI itself needs Node.js 22 or newer.

Beyond the CI report, the KYA toolkit gives you:

**OSS receipt report**

![KYA receipt report](docs/assets/overview.png)

**Hosted dashboard**

![KYA hosted dashboard](docs/assets/hosted-dashboard.png)

**Shared report page**

![KYA shared report](docs/assets/shared-report-page.png)

**Gateway**

![KYA gateway](docs/assets/gateway-home.png)

## Inputs

| Input | Default | Description |
|---|---|---|
| `fail-on` | `gap` | When the workflow fails: `gap` (any gap) or `never` (report only). Maps to `kya certify --fail-on`, which accepts exactly these two values; anything else exits 2 and the step reports `status=error`. |
| `window-days` | `30` | Look-back window in days for agent-activity evidence. Maps to `kya certify --window`. |
| `comment-on-pr` | `true` | Post the gap summary as a PR comment (status pill, pass/gap counts, top gaps). |
| `kya-version` | `latest` | Version, dist-tag or range of `@shield-agent/kya` to install (for example `0.29.0`, `latest`, `^0.29`). Values containing `:`, `/`, `\` or whitespace (npm aliases, git, file or URL specs) are refused. |

## Outputs

| Output | Description |
|---|---|
| `exit-code` | Exit code of `kya certify` (0 = clean, 1 = gaps, 2+ = error). Empty when certify was not run because the report path is unsafe. |
| `status` | Certify outcome: `pass` (exit 0), `gap` (exit 1), or `error` (any other exit code, a `PROJECT_PATH_REFUSED` refusal, or a symlinked or out-of-workspace report path). |

## Links

- OSS repo: https://github.com/The-Pixel-Boys/shield-agent
- npm: https://www.npmjs.com/package/@shield-agent/kya
- Hosted: https://shield-agent.com

## License

MIT. See [LICENSE](LICENSE).
