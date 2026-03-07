# Releasing reqstool

This guide documents the dependency graph between reqstool repositories and the order in which
releases should be performed.

## Dependency Graph

Release tiers top-down — all repos in a tier must be released before moving to the next.
Within each tier, repos can be released in any order or in parallel.

| Tier | Python | Java | TypeScript / Other |
|------|--------|------|--------------------|
| **1** — no reqstool deps | reqstool-python-decorators | reqstool-java-annotations | reqstool-typescript-tags |
| **2** — depends on Tier 1 | reqstool-python-hatch-plugin (← decorators) | reqstool-java-maven-plugin (← annotations) | |
| | reqstool-python-poetry-plugin (← decorators) | reqstool-java-gradle-plugin (← annotations) | |
| **3** — depends on Tier 2 | reqstool-client (← decorators + hatch-plugin) | | reqstool-vscode-extension |
| **4** — depends on Tier 3 | reqstool-demo (← client) | | |

### Independent (no code dependencies)

- **reqstool.github.io** — documentation site, can be released at any time
- **reqstool-ai** — standalone, no reqstool dependencies

## Release Order

1. Release all **Tier 1** repos first.
2. Update dependency versions in **Tier 2** repos, then release them.
3. Update dependency versions in **Tier 3** repos, then release them.
4. Update dependency versions in **Tier 4** repos, then release them.

## Notes

- Always verify that downstream repos pass CI after bumping an upstream dependency.
- Renovate will automatically create PRs for dependency updates in most repos.
