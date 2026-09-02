# reqstool/.github

This repository contains organisation-wide community health files and governance for the
[reqstool](https://github.com/reqstool) GitHub organisation.

Files placed here are automatically used by GitHub as defaults for all repositories in the
organisation that do not provide their own.

## Versioning

This repository is consumed by every other repo in the organisation, so a change here
reaches all of them. **It is versioned with tags, and consumers pin to a commit SHA rather
than to `main`.**

```yaml
uses: reqstool/.github/.github/workflows/common-release-prepare.yml@<sha> # 1.0.0
```

The SHA is what actually resolves; the `# <version>` comment is what makes it readable and
is what Renovate keys off. A bare `@1.0.0` would not do — a tag is mutable, so CodeQL's
`actions/unpinned-tag` flags it, and it would reintroduce exactly the problem pinning solves.
Tags carry no `v` prefix, matching every other repo in the organisation.

Renovate keeps these current: `.github/renovate.json5` digest-pins everything outside
`actions/*` and `github/*`, so a new tag here opens a bump PR in each consumer with the
digest and the comment rewritten together.

### Cutting a new version

**Merging to `main` does not release anything.** Consumers stay on whatever tag they pin
until a new one exists, so a fix merged here and never tagged reaches nobody — and Renovate
has nothing to propose. Tag after merging a change consumers need:

```bash
git tag 1.1.0 && git push origin 1.1.0
```

Then let Renovate raise the bumps rather than editing consumers by hand.

Use ordinary semver judgement about what the change means *to a consumer*: a new input or
workflow is a minor, a fixed workflow is a patch, and removing or renaming a workflow, an
action, or a required input is a major — that last one breaks every caller that names it.

This is deliberately not the flow in [`RELEASING.md`](RELEASING.md). That describes how the
*other* repos publish to PyPI, npm, Maven Central and the marketplaces. Nothing here is
published to a registry, so a tag is the whole release.

## Contents

| File / Directory | Purpose |
|---|---|
| `CODE_OF_CONDUCT.md` | Contributor Covenant — shared across all repos |
| `CONTRIBUTING.md` | Contribution guide, commit conventions, DCO instructions |
| `SECURITY.md` | Vulnerability reporting policy |
| `dco.txt` | Developer Certificate of Origin v1.1 |
| `.github/ISSUE_TEMPLATE/` | Issue templates (bug report, feature request, other) |
| `.github/PULL_REQUEST_TEMPLATE/` | Pull request template |
| `.github/CODEOWNERS.md` | Code ownership documentation |
| `.github/semantic.yml` | Semantic PR / commit configuration ([semantic-prs](https://github.com/apps/semantic-prs)) |
| `.github/workflows/check-semantic-pr.yml` | Reusable workflow for semantic PR validation |
| `.github/renovate.json5` | Renovate dependency update configuration |

## Related

- [`safe-settings/`](safe-settings/) — org-wide repository settings, rulesets and environments, as code
- [reqstool Discussions](https://github.com/orgs/reqstool/discussions) — Community Q&A
