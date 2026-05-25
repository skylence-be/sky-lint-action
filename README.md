# Skylence Lint Action

GitHub Action that lints [Skylence](https://skylence.io) `.sky` workflow files and annotates pull requests with any findings. Optionally uploads SARIF to the GitHub Security tab.

The action installs the `sky` CLI, runs `sky lint`, and turns each finding into an inline PR annotation. The job fails when lint finds problems, so a broken workflow blocks the merge.

## Quick start

Add a workflow at `.github/workflows/sky-lint.yml`:

```yaml
name: Skylence Lint
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - uses: skylence-be/sky-lint-action@v1
```

That lints `.sky/workflows/` in the checked-out repo against the latest `sky` release.

## Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `version` | `latest` | `sky` release tag to install (e.g. `v0.5.1`). `latest` resolves to the newest published release. |
| `scope` | `repo` | `repo` lints `.sky/workflows/` only. `all` adds the workspace and user tiers. |
| `sarif` | `false` | When `true`, generates SARIF 2.1.0 and uploads it to the Security tab. |

## Pinning a version

Pin the `sky` CLI for reproducible runs:

```yaml
- uses: skylence-be/sky-lint-action@v1
  with:
    version: v0.5.1
```

## SARIF upload

To surface findings under Security → Code scanning, grant the permission and enable the input:

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v6
      - uses: skylence-be/sky-lint-action@v1
        with:
          sarif: true
```

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Clean. No problems. |
| 1 | Lint found one or more problems. |
| 2 | Tool error (bad input, install failure). |

## Annotations

Each finding becomes a GitHub workflow command:

```
::error file=workflow.sky,line=3,title=SKY-WF-002::workflow: name is required
```

Annotations show inline on the PR diff when the file is in the changed set.
