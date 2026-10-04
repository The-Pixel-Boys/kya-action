# Examples

More real-world workflows for `shield-agent/kya-action`.

## 1. Certify on a weekly schedule

Runs the Agent Trust Baseline every Monday morning against the last 90 days of
agent activity, without ever failing the job — useful as a drift alarm that you
can review from the artifacts instead of a red pipeline.

```yaml
name: KYA Weekly Baseline
on:
  schedule:
    - cron: '17 6 * * 1' # Mondays 06:17 UTC
  workflow_dispatch:

permissions:
  contents: read

jobs:
  certify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: shield-agent/kya-action@v1
        with:
          fail-on: never
          window-days: 90
          comment-on-pr: false

      - name: Upload weekly report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: kya-weekly-baseline
          path: .kya/certify/
          retention-days: 90
```

## 2. Certify + signed evidence bundle as a release artifact

On every version tag, run `kya certify --sign` to produce a signed evidence
bundle and attach it to the GitHub Release, so consumers can verify the trust
baseline for the exact code they are running.

```yaml
name: Release
on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  certify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: shield-agent/kya-action@v1
        with:
          fail-on: never
          comment-on-pr: false

      - name: Produce signed evidence bundle
        run: kya certify --fail-on never --sign

      - name: Attach evidence bundle to release
        uses: softprops/action-gh-release@v2
        with:
          files: |
            .kya/certify/*
```
