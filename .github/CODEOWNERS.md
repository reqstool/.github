# Code Owners

The designated code owner for the reqstool organisation is the `@reqstool/maintainers` team.

## How CODEOWNERS works on GitHub

GitHub does **not** propagate a `CODEOWNERS` file from the org `.github` repo to other
repositories. Each repository that should enforce code-owner reviews must contain its own
`CODEOWNERS` file (no extension) placed in one of these locations (in precedence order):

1. `CODEOWNERS` — repository root
2. `.github/CODEOWNERS`
3. `docs/CODEOWNERS`

## Standard CODEOWNERS content

Add the following to a `CODEOWNERS` file in each repository:

```
* @reqstool/maintainers
```

This designates `@reqstool/maintainers` as the required reviewer for all files.

## Enabling enforcement

Code-owner review is only enforced when **branch protection** is configured with
`require_code_owner_reviews = true` for the target branch. This is managed via Terraform in the
[reqstool/.github-private](https://github.com/reqstool/.github-private) repository.
