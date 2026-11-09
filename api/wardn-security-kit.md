---
layout: default
title: "wardn/security-kit"
parent: API Reference
nav_order: 2
---

# wardn/security-kit

Bitwarden security readiness kit PDF generation (a placeholder for now).

## Functions

### generateSecurityKit()

Fill in the Bitwarden security readiness kit PDF (etc/bw-security-kit.pdf) with the last updated date and vault
URL, writing it to bitwarden-security-kit.pdf in the current directory (replacing any existing one) and opening
it. Outputs the two filled-in values. A placeholder for now (see the TODO in it).


*env vars*

| | |
|---|---|
| `vaultUrl` | The Bitwarden vault URL, for the kit's vault URL field. |
{: .args-table}

