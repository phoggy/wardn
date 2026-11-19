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
brew tap rayvn-central/tap
brew trust --tap rayvn-central/tap
brew install wardn
```

Homebrew installs formulae from taps other than its own only once you trust them, hence `brew trust`.

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

## Best Practices

A backup holds your whole vault, so it needs the care the vault itself gets. One that includes your 2FA tokens (see
[Including other files](https://github.com/phoggy/wardn#including-other-files)) holds your second factors as well: that
is what makes it a complete recovery set, opened by your valt key alone, and why these practices matter.

- **Follow valt's [best practices](https://rayvn.ink/valt/#best-practices):** keep backups apart from your paper key,
  treat a paper key with the passphrase written on it as a complete key, keep a copy of the passphrase you can reach
  without Bitwarden, and type it only on a computer you trust.
- **Keep more than one backup, in more than one place,** e.g. on a NAS and in cloud storage: a backup is only useful if
  it survives whatever happened to the original.
- **Keep the set current.** Back up after changing your vault, and export included files again when they change (wardn
  warns about any older than 90 days).
- **Keep Bitwarden's two-step login recovery code in the vault,** as a secure note, so that every backup has it. If you
  lose your two-step login device, it is in the backup's vault export: `valt decrypt BACKUP --extract` gives it. That
  writes your whole vault, unencrypted, to the current directory: do it on a computer you trust, and delete the files as
  soon as you have the code.
- **Practice a restore.** Once in a while, say yearly, restore a backup into a separate Bitwarden account made for the
  purpose, using only your paper key and its passphrase, as you would after losing everything. It shows that the backup,
  the key and the steps all work, while you can still fix them.

## Libraries

| Library | Description |
|---|---|
| [wardn/backup](/wardn/api/wardn-backup) | Vault backup archives. |

## Related Projects

- [rayvn](/rayvn) — the shared library framework wardn is built on
- [valt](/valt) — the encryption and [secure archives](/valt/api/valt-archive#secure-archives) wardn uses
