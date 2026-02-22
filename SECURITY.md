# Security Policy

## Supported Versions

Only the **latest release** of each reqstool component receives security fixes.
Older versions are not actively patched; please upgrade to the latest release.

| Status            | Version      |
|-------------------|--------------|
| Actively supported | Latest       |
| Not supported      | All older    |

---

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Report vulnerabilities privately using a
[GitHub private security advisory](https://github.com/reqstool/.github/security/advisories/new).
This keeps the details confidential while we work on a fix.

### What to include

- A clear description of the vulnerability
- The affected component(s) and version(s)
- Steps to reproduce or a proof-of-concept (if available)
- Potential impact assessment

### Response

This is a volunteer-maintained open-source project. We will do our best to respond and
investigate reports in a timely manner, but cannot commit to specific response times.

We follow [coordinated disclosure](https://en.wikipedia.org/wiki/Coordinated_vulnerability_disclosure):
we will work with you to agree on a disclosure timeline before publishing details.

---

## Scope

The following are considered **in scope** as security issues:

- Authentication or authorisation bypass
- Arbitrary code execution via untrusted input
- Sensitive data exposure (credentials, tokens, private data)
- Dependency vulnerabilities with a clear exploit path in reqstool

The following are **out of scope** and should be filed as regular bugs:

- Issues requiring physical access to the machine
- Denial-of-service via resource exhaustion with no exploit
- Issues in development/test tooling with no production impact
- General software bugs without a security impact

---

## Disclosure Credits

We are happy to credit researchers who responsibly disclose vulnerabilities, unless they prefer
to remain anonymous.
