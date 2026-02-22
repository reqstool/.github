# Contributing to reqstool

Thank you for your interest in contributing to reqstool! We welcome contributions of all kinds —
bug reports, feature requests, documentation improvements, and code changes.

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) in all interactions.

---

## Reporting Issues

Use the issue templates when opening a new issue:

- **Bug report** — unexpected behaviour or crashes
- **Feature request** — ideas for new functionality or improvements
- **Other** — anything else

Before submitting, search existing issues to avoid duplicates. For general questions and
discussions, use [GitHub Discussions](https://github.com/orgs/reqstool/discussions).

---

## Submitting Changes

1. **Fork** the relevant repository and clone your fork locally.
2. **Create a branch** from `main` with a descriptive name:
   ```
   git checkout -b feat/my-feature
   ```
3. **Make your changes** and ensure existing tests pass.
4. **Commit** following the [Commit Messages](#commit-messages) conventions below, signing off
   each commit per the [Developer Certificate of Origin](#developer-certificate-of-origin).
5. **Push** your branch and open a Pull Request against `main`.
6. Fill in the PR template completely. Link any related issues.

---

## Commit Messages

All commits and PR titles **must** follow [Conventional Commits](https://www.conventionalcommits.org/).
Our [semantic-prs](https://github.com/apps/semantic-prs) check enforces this automatically on
every PR.

### Format

```
<type>(<scope>): <short description>
```

### Allowed types

| Type       | When to use                                     |
|------------|-------------------------------------------------|
| `feat`     | New feature                                     |
| `fix`      | Bug fix                                         |
| `refactor` | Code restructure without behaviour change       |
| `chore`    | Routine maintenance, tooling                    |
| `security` | Security fixes or improvements                  |
| `revert`   | Reverts a previous commit                       |

### Allowed scopes

| Scope           | Area                                              |
|-----------------|---------------------------------------------------|
| `reqs`          | Requirements tracking core logic                  |
| `docs`          | Documentation                                     |
| `tests`         | Test infrastructure                               |
| `build`         | Build tooling                                     |
| `ci`            | CI/CD pipelines                                   |
| `conf`          | Configuration                                     |
| `api`           | Public API surface                                |
| `core`          | Core shared logic                                 |
| `deps`          | Dependency management                             |
| `release`       | Release process                                   |
| `github-actions`| GitHub Actions updates (used by Renovate)         |

The canonical config lives at [`.github/semantic.yml`](.github/semantic.yml).

### Examples

```
feat(reqs): add support for YAML requirement files
fix(api): correct status code on empty result set
chore(deps): bump requests from 2.31 to 2.32
```

---

## Developer Certificate of Origin

All contributions must be signed off with the
[Developer Certificate of Origin v1.1](dco.txt). This certifies that you wrote the contribution
or have the right to submit it under the project's open-source licence.

To sign off, add a `Signed-off-by` trailer to every commit using the `-s` flag:

```
git commit -s -m "feat(reqs): add my feature"
```

This produces:

```
feat(reqs): add my feature

Signed-off-by: Your Name <you@example.com>
```

Your name and email must match your Git identity. If you have forgotten to sign off, you can
amend recent commits:

```
git commit --amend --signoff
git rebase --signoff HEAD~N   # sign N previous commits
```

---

## Code Review

- All PRs require at least **one approving review** from a maintainer before merge.
- Reviews are provided on a **best-effort** basis; please allow reasonable time for a response.
- Maintainers may request changes or ask clarifying questions before approving.
- Once approved and all checks pass, a maintainer will merge the PR using squash merge.
