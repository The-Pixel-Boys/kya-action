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

Reports (JSON/MD/HTML) are written to `.kya/certify/` so you can upload them as workflow artifacts. When `fail-on: never`, the step never fails the job and the exit code is still exposed via the outputs and the PR comment.

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
| `kya-version` | `latest` | Version of `@shield-agent/kya` to install. |

## Outputs

| Output | Description |
|---|---|
| `exit-code` | Exit code of `kya certify` (0 = clean, 1 = gaps, 2+ = error). |
| `status` | Certify outcome: `pass`, `gap`, or `error`. |

## Links

- OSS repo: https://github.com/The-Pixel-Boys/shield-agent
- npm: https://www.npmjs.com/package/@shield-agent/kya
- Hosted: https://shield-agent.com

## License

MIT. See [LICENSE](LICENSE).
