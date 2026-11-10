---
layout: home
title: Home
nav_order: 1
---

# wardn

Encrypted [Bitwarden](https://bitwarden.com/) vault backup and restore. Built on [rayvn](/rayvn) and [valt](/valt).

wardn exports your Bitwarden vault, attachments included, with the Bitwarden CLI, and saves it as a [valt](/valt)
[*secure archive*](/valt/api/valt-archive#secure-archives): encrypted with age and signed with your valt key, so that
tampering is detected on restore. Restoring verifies and decrypts a backup, then imports it into a vault, attachments
and all.

Your credentials are never stored: logging in and unlocking always ask for them. The unencrypted vault data is kept only
in memory-backed storage while wardn works, never on disk, unless none is available and you agree to use the disk.

## First Look

```bash
valt keys                    # create your valt key pair first, if you don't have one
wardn backup                 # writes an encrypted, signed backup of your vault
wardn restore BACKUP_FILE    # verifies, decrypts and imports a backup into a vault
```

- Backups are encrypted to your own valt key. Add others with `-r AGE_PUBLIC_KEY` or `-R their.pub`, or leave yours out
  with `--no-self`.
- With a [Bitwarden personal API key](https://bitwarden.com/help/personal-api-key/) set in the `BW_CLIENTID` and
  `BW_CLIENTSECRET` environment variables, logging in asks only for your master password.
- A backup records the Bitwarden server it was made from, e.g. `https://vault.bitwarden.eu`, and is restored to it
  unless `-u` gives another.
- `valt decrypt BACKUP` recognizes a wardn backup, and offers to restore it with wardn: installed, or with Nix or
  Homebrew.
- Backups made by earlier versions of wardn (age encrypted tar files) can still be restored.

See the [CLI reference](/wardn/cli/) for every option.

## Install

With [Homebrew](https://brew.sh):

```bash
brew tap rayvn-central/brew && brew install wardn
```

Or with [Nix](https://nixos.org/download/):

```bash
nix profile add github:phoggy/wardn
```

With Nix on macOS, also install the Bitwarden CLI (`bw`), e.g. with `brew install bitwarden-cli`: it can't be built by
Nix there, so wardn uses the one on your PATH. On Linux, Nix includes it.

See the [README](https://github.com/phoggy/wardn#installation) for installing Nix, upgrading and other options.

## Restore Without Installing

To restore a backup on a computer without wardn, only [Nix](https://nixos.org/download/) is needed (and, on macOS, the
Bitwarden CLI, as above):

```bash
nix run github:phoggy/wardn#restore -- restore BACKUP_FILE -i KEY_FILE
```

## Libraries

| Library | Description |
|---|---|
| [wardn/backup](/wardn/api/wardn-backup) | Vault backup archives. |

## Related Projects

- [rayvn](/rayvn) — the shared library framework wardn is built on
- [valt](/valt) — the encryption and [secure archives](/valt/api/valt-archive#secure-archives) wardn uses
