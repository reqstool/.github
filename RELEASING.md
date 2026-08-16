# Releasing reqstool

Every reqstool repository releases the same way, through the reusable workflows in this
repo. This document is the reference for that flow; the dependency graph at the end says
what order to release things in.

## Versioning: there is nothing to bump by hand

**The git tag is the only version.** No repository holds a version string a human edits —
each build tool derives it from git state:

| Ecosystem | Mechanism |
|---|---|
| Python / Hatch | `hatch-vcs` |
| Python / Poetry | `poetry-dynamic-versioning` |
| Java / Maven | [Maveniverse Nisse](https://github.com/maveniverse/nisse) — `<version>${nisse.jgit.dynamicVersion}</version>` |
| Java / Gradle | [`io.github.jimisola.git-dyn-semver`](https://github.com/jimisola/git-dyn-semver-gradle-plugin) |
| npm / VS Code | no equivalent exists, so the workflows write the tag into `package.json` before building |

This is why every build workflow checks out with `fetch-depth: 0` and `fetch-tags: true`: a
shallow clone makes these tools compute the *wrong* version rather than fail, which is the
worst of both.

Tags carry no `v` prefix, in any ecosystem.

## Cutting a release

1. Merge what should be in the release to `main`. Commit subjects must follow
   [Conventional Commits](https://www.conventionalcommits.org/) —
   `common-check-semantic-pr.yml` enforces that on every PR, so it should already be true.

2. **Preview it: run the repo's Release workflow with `dry-run` left on** (it defaults to
   on). This resolves the version, generates the changelog, and shows both in the job
   summary alongside the raw commits they were derived from — without tagging or creating
   anything. That last part is the actual check: anything in the commit list but missing
   from the notes was dropped for a reason (an unconventional subject, or a skipped
   `ci:`/`build:` type), which is how a mistyped commit type gets caught before it becomes
   a wrong version bump.

3. Run it again with `dry-run` unchecked:

   - **`version`** — leave empty to auto-detect. git-cliff computes the next version from
     the Conventional Commits since the last tag: `feat:` bumps the minor, `fix:` the
     patch, `!`/`BREAKING CHANGE:` the major. **Below 1.0 a breaking change bumps the minor
     instead** — see [Getting to 1.0.0](#getting-to-100).
   - **`ref`** — branch to release from. Empty means the branch you dispatched on. Must be
     `main`, `hotfix/*`, or `release/*`; anything else is rejected before a tag is created.
     A raw commit SHA is rejected for the same reason — release from the branch containing
     it, so the release is traceable to one.
   - **`force`** — only needed when you pass a `version` that *disagrees* with the
     auto-detected one. Without it a mismatch is a hard error naming both numbers. That is
     the guard that catches "meant 0.3.0, typed 0.2.0" before it becomes a tag.
   - **`prerelease`** — leave at `none` for a real release. See
     [Cutting a release candidate](#cutting-a-release-candidate).

4. Lint and the full build run, so what you approve next is already green.

5. **The run pauses for approval.** The job that tags is bound to the `stable` environment,
   so it sits pending until a required reviewer approves it on the run page. There is no
   draft to publish by hand — this is the confirmation step.

6. On approval it tags the ref and creates the GitHub Release **as a prerelease**.

7. The project is rebuilt *from the tag* — which is what gives the artifacts their version
   — and those artifacts are checked and attached to the prerelease.

   The Java repos skip this step: `mvn deploy` and `./gradlew publishPlugins` build from the
   tag themselves, so there is nothing to rebuild and nothing to attach twice. The check
   still happens, as an assertion inside the publish step that the resolved version equals
   the tag. Their GitHub releases therefore carry no jars — Maven Central and the Plugin
   Portal are the distribution channel.

8. The artifacts are published to the registry.

9. Only then is the prerelease promoted to the latest release. **A release candidate stops
   at step 8 instead**, staying a prerelease permanently.

Promotion is deliberately last: until it runs, nothing resolving "the latest release" can
see what was built, so every step that can fail has already succeeded by the time anyone is
served it. Promotion itself is one API call against a release that already has its
artifacts.

### The three environments

All declared for every repo in `reqstool/.github-private`'s safe-settings config —
**without them the approval steps are inert and a release runs straight through**, because
GitHub creates a missing environment on demand with no protection rules.

| Environment | Gates | Reviewer |
|---|---|---|
| `release` | Creating the tag and the prerelease. Runs for a release candidate too. | required |
| `stable` | Publishing to a real index — PyPI, Maven Central, the Plugin Portal, the marketplaces. Only a final release reaches it. | required |
| `test` | Staging publishes, e.g. Test PyPI. | none — a dev build lands there on every push to main |

The split matters: `release` gates something reversible (a tag and a prerelease can be
deleted), `stable` gates something that cannot be undone. Naming the tag gate `stable` would
also read strangely when approving a release candidate, which never becomes stable.

### Why a prerelease rather than a draft

The release has to be verifiable before anyone can reach it, and those two pull in opposite
directions. A draft is invisible to the verification too — `/releases/tags/<tag>` returns
404 to an unauthenticated fetch — so there would be nothing to check.

A prerelease is readable by exact tag, but `/releases/latest` excludes it. So the release is
fully testable while staying invisible to anything resolving "the latest release", until
step 9.

If something fails in between, the release stays a prerelease: nobody was served it. The tag
and prerelease are left in place for a human to delete or supersede — fixing forward with a
patch version is usually cleaner than deleting a pushed tag.

This also closes a window the old flow had: artifacts were attached *after* publication, so
for a short time the release existed with nothing to download.

## Cutting a release candidate

Set `prerelease` to `rc` (or `b`/`a`) and run the workflow as normal. It does everything a
real release does — tags, builds, asserts the artifacts, publishes with assets attached —
and then **stops before step 9**.

- **The number is chosen for you.** git-cliff only ever emits final versions, so the
  workflow appends the next unused suffix to whatever it resolved: `0.5.0` becomes the
  candidate, and running it again gives the next one. You don't pass `version`, and you
  don't need `force` — the guard compares the *base*, which is unchanged.
- **The spelling is per-ecosystem**, and they are not interchangeable:

  | format | `0.5.0` + `rc` | why |
  |---|---|---|
  | `pep440` | `0.5.0rc1` | PEP 440 normalises away a separator, so a hyphenated tag would stop matching the built filename |
  | `semver` | `0.5.0-rc.1` | the dot-separated identifier is what sorts below `0.5.0` |
  | `maven` | `0.5.0-rc1` | Maven's `ComparableVersion` ranks the qualifier below an unqualified version only when hyphen-separated |

- **Candidates are invisible to versioning.** `cliff.toml`'s `tag_pattern` is anchored at
  both ends, so an rc tag is not a release boundary: the eventual `0.5.0` is still computed
  from the last stable tag, and its notes still span everything since that tag rather than
  starting at the last candidate.
- **Not every registry accepts one.** The VS Code Marketplace requires a strict `x.y.z` and
  rejects `0.5.0-rc.1`, so in `reqstool-vscode` an rc produces a GitHub prerelease with the
  VSIX attached but is not published to either marketplace. Testers install the VSIX by hand.

Shipping the real release afterwards is just the workflow again with `prerelease: none`.
The candidates' tags stay where they are; nothing needs deleting.

### Getting to 1.0.0

Auto-detection will never propose it. While a project is at 0.x, `cliff.toml`'s
`breaking_always_bump_major = false` makes a `!`/`BREAKING CHANGE:` commit bump the *minor*
(`0.1.0` → `0.2.0`) rather than jumping to `1.0.0` — otherwise a routine breaking change
during pre-1.0 development would declare the API stable as a side effect of a commit
message.

So 1.0.0 is cut deliberately: run Release with `version: 1.0.0` and `force: true`. `force`
is required precisely because the value disagrees with what git-cliff computed — that guard
is what makes this an explicit decision rather than a typo. From the first 1.x tag onward
the mapping is ordinary semver again, with no config change needed.

## The workflows

Four reusable workflows make up the flow. Each repository's own `release.yml` wires them
together with its own lint, build and publish jobs — a reusable workflow cannot call back
into the caller's workflows, which is why this is four pieces rather than one.

| Workflow | Does |
|---|---|
| `common-release-prepare.yml` | Resolves the version, generates the notes, writes the summary. Nothing durable — a dry run is this and nothing else. |
| `common-release-tag.yml` | The approval gate. Tags, pushes, creates the prerelease. |
| `common-release-assets.yml` | Asserts the artifacts carry the version, attaches them. |
| `common-release-promote.yml` | Promotes to latest. A no-op for a release candidate. |

```
prepare  (dry-run stops here)
  → lint + build          the repo's own workflows, on the branch
  → [approval] tag        common-release-tag.yml
  → build @ tag           the repo's own build.yml, ref = the tag
  → assets                common-release-assets.yml
  → publish               python-publish-to-pypi.yml / java-publish-to-maven.yml / …
  → promote               common-release-promote.yml
```

`common-check-release.yml` is separate: it guards a release created by hand in the UI,
enforcing the same tag-format and branch rules the flow enforces before tagging.

### A note on `$/`

The reusable workflows above reference this repository's composite actions as
`$/.github/actions/…`. That is [self-repository
syntax](https://github.blog/changelog/2026-07-30-reference-same-repository-actions-with-self-repository-syntax/):
it resolves to *this* repository at the exact commit running, not the caller's checkout,
which is where a workspace-relative `./` would look. A caller that pins a workflow by SHA
therefore gets the actions at that same SHA, and the two cannot drift apart.

Two consequences worth knowing:

- **actionlint does not understand `$/` yet** and rejects it as a malformed `uses:`
  ([rhysd/actionlint#711](https://github.com/rhysd/actionlint/issues/711)). `ci.yml` passes a
  message-scoped `-ignore` for exactly that error; drop it once upstream lands support. A
  genuinely unpinned action still fails the lint.
- **It needs runner 2.336.0 or newer** and is not available on GitHub Enterprise Server.
  Both are fine for GitHub-hosted runners on github.com.

The rules those actions enforce are tested by `tests/actions/run-tests.sh`, which runs the
scripts directly rather than through a workflow — so a PR is tested by the PR.

## Commit type → changelog section

Set by `.github/cliff.toml`, matching the types `common-check-semantic-pr.yml` enforces:

| Commit type | Changelog section |
|---|---|
| `security` | Security |
| `feat` | Features |
| `fix` | Bug Fixes |
| `perf` | Performance |
| `refactor` | Refactoring |
| `docs` | Documentation |
| `test` | Testing |
| `style` | Style |
| `revert` | Reverts |
| `chore` | Miscellaneous |
| `ci`, `build` | omitted — internal tooling, not user-facing |

A `ci!:` or `build!:` still appears, via `protect_breaking_commits`: a change that breaks a
consumer's build must reach them regardless of its type.

Commits that don't parse as Conventional Commits are skipped entirely
(`filter_unconventional = true`), which is why every commit needs a properly-typed subject.

Each line carries `by @user`, and `in #N` when it resolves. `remote.pr_number` only ever
resolves for a **squash merge** — git-cliff matches a commit's SHA against a closed PR's
`merge_commit_sha`, which a real merge commit's constituent commits never equal.

---

## Release order across repositories

Release tiers top-down — all repos in a tier must be released before moving to the next.
Within each tier, repos can be released in any order or in parallel.

| Tier | Python | Java | TypeScript / Other |
|------|--------|------|--------------------|
| **1** — no reqstool deps | reqstool-python-decorators | reqstool-java-annotations | reqstool-typescript-tags |
| **2** — depends on Tier 1 | reqstool-python-hatch-plugin (← decorators) | reqstool-java-maven-plugin (← annotations) | |
| | reqstool-python-poetry-plugin (← decorators) | reqstool-java-gradle-plugin (← annotations) | |
| **3** — depends on Tier 2 | reqstool-client (← decorators + hatch-plugin) | | reqstool-vscode |
| **4** — depends on Tier 3 | reqstool-demo (← client) | | |

### Independent (no code dependencies)

- **reqstool-docs** — documentation site, can be released at any time
- **reqstool-ai** — standalone, no reqstool dependencies

Steps:

1. Release all **Tier 1** repos first.
2. Update dependency versions in **Tier 2** repos, then release them.
3. Update dependency versions in **Tier 3** repos, then release them.
4. Update dependency versions in **Tier 4** repos, then release them.

Renovate opens the dependency-bump PRs automatically in most repos. Always verify a
downstream repo passes CI after bumping an upstream dependency.
