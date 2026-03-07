# Releasing reqstool

This guide documents the dependency graph between reqstool repositories and the order in which
releases should be performed.

## Dependency Graph

```
Tier 1 (no reqstool deps — release first)
├── reqstool-python-decorators
├── reqstool-java-annotations
└── reqstool-typescript-tags

Tier 2 (depends on Tier 1)
├── reqstool-python-hatch-plugin      ← depends on reqstool-python-decorators
├── reqstool-python-poetry-plugin     ← depends on reqstool-python-decorators
├── reqstool-java-maven-plugin        ← depends on reqstool-java-annotations
└── reqstool-java-gradle-plugin       ← depends on reqstool-java-annotations

Tier 3 (depends on Tier 2)
├── reqstool-client                   ← depends on reqstool-python-decorators + reqstool-python-hatch-plugin
└── reqstool-vscode-extension         ← independent but may reference reqstool-client

Tier 4 (depends on Tier 3)
└── reqstool-demo                     ← uses reqstool-client at runtime
```

### Independent (no code dependencies)

- **reqstool.github.io** — documentation site, can be released at any time
- **reqstool-ai** — standalone, no reqstool dependencies
- **reqstool-test-packages** — internal test infrastructure

## Release Order

1. Release all **Tier 1** repos first (order within tier does not matter).
2. Update dependency versions in **Tier 2** repos, then release them.
3. Update dependency versions in **Tier 3** repos, then release them.
4. Update dependency versions in **Tier 4** repos, then release them.

Within each tier, repos can be released in any order or in parallel.

## Notes

- Always verify that downstream repos pass CI after bumping an upstream dependency.
- Renovate will automatically create PRs for dependency updates in most repos.
