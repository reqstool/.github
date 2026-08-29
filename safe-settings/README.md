# Org-wide configuration (safe-settings)

Org-wide repository configuration for the [reqstool](https://github.com/reqstool) GitHub
organization. Moved here from `.github-private`, which is being retired.

## Org-wide repository settings via `github/safe-settings`

Repository settings are enforced across all non-archived repos using
[github/safe-settings](https://github.com/github/safe-settings). The workflow
(`.github/workflows/safe-settings.yml`) runs on every push to `main` that touches
`safe-settings/`, and as a weekly cron job for drift correction.

Configuration files:
- `settings.yml` — org-wide repository defaults
- `suborgs/all.yml` — the `protect-main` ruleset and release environments
- `deployment-settings.yml` — scope; `.github` excludes itself, so this config is not self-applied

### GitHub App setup (manual, one-time)

safe-settings requires a GitHub App installed on the org:

1. **Create the app** in https://github.com/organizations/reqstool/settings/apps
   - Required permissions:
     - `Repository administration: Write` — repo settings, rulesets, vulnerability-alert toggles
     - `Repository contents: Read` — reads `safe-settings/*.yml` from this repo
     - `Repository issues: Write` — **labels are part of the Issues permission**,
       and error issues when `CREATE_ERROR_ISSUE` is on
     - `Repository environments: Write` — the `environments:` block in `suborgs/all.yml`
     - `Repository metadata: Read` — mandatory, granted automatically

   That is the minimal set for the four plugin keys this config uses: `repository`,
   `labels`, `rulesets` and `environments`. The upstream docs list far more because
   they cover every plugin, including ones this config never touches.

   Adding a plugin key means adding its permission — and **added** permissions must
   be approved on the installation before they take effect, while **removed** ones
   apply immediately. So widening the config is the step that needs a click, not
   narrowing it.

> **Preview mode does not work.** safe-settings has no `DRY_RUN` variable — the knob
> is `FULL_SYNC_NOP`, exposed as the `nop` input on manual dispatch. In 2.1.18 the
> NOP reporting path crashes: `lib/settings.js:274` dereferences
> `y.action.additions` before the `undefined` guard three lines below it, and
> disabling `CREATE_PR_COMMENT` only moves the crash elsewhere. Diff the intended
> config against the live API by hand instead.
2. **Install the app** on *All repositories* in the reqstool org
3. **Generate a Private Key** from the app settings page (download the `.pem`)
4. **Add to this repo** (https://github.com/reqstool/.github/settings):
   - Variable `SAFE_SETTINGS_APP_ID` → the App ID integer
   - Secret `SAFE_SETTINGS_PRIVATE_KEY` → full contents of the `.pem` file

> **Note:** Secret scanning (for public repos) is not configurable via safe-settings
> YAML and must be enabled manually per repo or via the GitHub org security settings.

---

## Org-level security settings (manual, one-time)

These settings live at **github.com/organizations/reqstool/settings/security_analysis**
and cannot be managed by safe-settings (which is repo-scoped only).

### What was configured and why

| Setting | State | Reason |
|---------|-------|--------|
| Dependabot alerts | **On** | Free; alerts only, no PRs created |
| Dependabot grouped security updates | **Off** | Renovate owns dependency updates; enabling this creates duplicate PRs |
| Secret scanning (alerts) | **On** | Free for public repos; already active |
| Secret scanning push protection | **On** | Free for public repos; blocks accidental secret commits |

### Paid features — skipped for now

The following require GitHub Advanced Security (GHAS) or Code Security (~$30/committer/month)
and are out of scope on the current free plan:

- Extended CodeQL query suite recommendation
- Copilot Autofix
- Expanded CodeQL analysis (bulk org-level)
- Secret scanning push protection for **private** repos

### CodeQL per-repo setup (free for public repos)

Bulk enablement of CodeQL via the org UI requires GHAS. For public repos, it can be
enabled per repo for free via the API. One-time bootstrap — run locally:

```bash
gh repo list reqstool --visibility public --no-archived --json name --jq '.[].name' \
| while read repo; do
    echo "Enabling CodeQL on $repo..."
    gh api --method PATCH \
      /repos/reqstool/"$repo"/code-scanning/default-setup \
      -f state=configured \
      -f query_suite=extended \
      && echo "  OK" || echo "  FAILED (may need GHAS or repo has no supported language)"
  done
```

Repos with no supported language will fail gracefully and can be ignored.
