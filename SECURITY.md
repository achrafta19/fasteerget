# Security Policy

## Reporting a vulnerability

Report privately through **Security → Report a vulnerability** on GitHub, or via
GitHub's private advisory form. Please do not open a public issue for a
vulnerability.

Include: affected version/commit, reproduction steps, impact, and any suggested
remediation.

## What this project stores

- Passport numbers, national ID numbers, dates of birth, contact details
- Operator credentials (scrypt hashes only) and session tokens
- Appointment records, engine logs, and an append-only audit ledger
- BLS connector secrets held server-side only

**No plaintext password is ever written to the database, logs, or backups.**

## Hard rules for contributors

1. **CAPTCHAs stay human-solved.** Do not add OCR, solver services, or bypass
   mechanisms. The engine raises a challenge and waits for a person.
2. **Never log secrets.** No session cookies, passwords, or captcha tokens in
   `console.log`, error messages, or the audit ledger.
3. **Every record is owner-scoped.** All queries must filter by the signed-in
   operator id.
4. **No default credentials.** Do not reintroduce hardcoded usernames or
   passwords, even in comments, tests, or fixtures.
5. **Destructive actions require admin.** Deleting operators, changing booking
   limits, or editing connector secrets must be role-gated and audit-logged.

## Supported versions

| Version | Supported |
|---|---|
| `main` branch | Yes |
| Tagged releases | 12 months |

## Reporting scope

In scope: authentication bypass, IDOR on applicant/appointment records,
credential leakage, audit-ledger tampering, session fixation.

Out of scope: rate-of-success claims against BLS, availability of the upstream
portal, and automated CAPTCHA solving (deliberately absent by design).
