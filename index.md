---
layout: home
title: Home
nav_order: 1
---

# wardn

Encrypted Bitwarden vault backups, built on [rayvn](/rayvn) and [valt](/valt).

wardn exports your Bitwarden vault and encrypts it using age encryption, producing a backup you can store safely anywhere.

## Libraries

| Library | Description |
|---|---|
| [wardn/security-kit](/wardn/api/wardn-security-kit) | Bitwarden security readiness kit PDF generation |

## Getting Started

```bash
# Install via Nix
nix run github:phoggy/wardn

# Back up your Bitwarden vault
wardn backup
```

## Related Projects

- [rayvn](/rayvn) — the shared library framework wardn is built on
- [valt](/valt) — the encryption layer wardn uses
