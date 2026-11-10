---
layout: default
title: CLI Reference
nav_order: 2
---

# wardn CLI

wardn has two commands: `backup`, which writes an encrypted, signed backup of your Bitwarden vault, and `restore`,
which verifies, decrypts and imports one into a vault.

## Usage

```
Create a backup of a Bitwarden vault or restore a vault from one, as a valt secure archive.

Usage: wardn backup [-i IDENTITY] [-r RECIPIENT]... [-R PATH]... [--no-self] [-b BACKUP_DIR] [-z ZONE]
       wardn restore BACKUP_FILE [-i IDENTITY]

The Bitwarden CLI is used to access the vault. Login/unlock requires user input: credentials are never stored.
Using an API key simplifies login, requiring only master password input rather than full credentials. This is
enabled by setting the BW_CLIENTID and BW_CLIENTSECRET environment variables, for details see
https://bitwarden.com/help/personal-api-key/.

Backups are valt secure archives (see https://github.com/phoggy/valt): encrypted with age and signed with your valt
key, so that tampering is detected on restore. Your own public key (the .pub file next to the identity) is always a
recipient unless --no-self is given; create a valt key pair with valt keys. Backups made by earlier versions
of wardn (age encrypted tar files) can still be restored, with any age identity.

Note Both operations store unencrypted vault data temporarily. It is kept in memory (RAM backed storage)
rather than on disk, so that it cannot be recovered after it is deleted: storage set up by rayvn-tmp, /dev/shm on
Linux, or else a RAM disk created for the purpose on macOS. If none is available you will be asked whether to
continue using disk storage, from which deleted files may still be recoverable.

Options:

    -i, --identity PATH          Your valt private key file, used to sign backups and to restore them (default:
                                 valt's default key, see 'valt default-key': ~/.config/valt/alex.key).
    -r, --recipient RECIPIENT    Also encrypt to the specified RECIPIENT (age public key). May be repeated.
    -R, --recipients-file PATH   Also encrypt to the recipients listed at PATH, e.g. a valt .pub file. May be repeated.
    --no-self                    Do not include your own public key as a recipient.
    -b, --backup-dir PATH        Use the secure directory at PATH to store the encrypted backup.
    -p, --prefix PREFIX          Set a prefix for the backup file name.
    -z, --zone ZONE              The time zone for the timestamp in the backup file name: 'local', 'UTC' or a name
                                 such as 'America/Los_Angeles' (default: local, the system time zone).
    -u, --url URL                Set the URL for the Bitwarden server (default: https://vault.bitwarden.com; for a
                                 restore, the server the backup was made from, if it says).
    -l, --login                  Force full login even if API key environment variables are set.
    -v                           Print the version.
    --version                    Print the version and release date.
    -h, --help                   Print this help message.

Debug Options

    --debug                      Enable debug, write output to log file and show on exit.
    --debug-new                  Enable debug, clear log file, write output to log file and show on exit.
    --debug-out                  Enable debug, write output to the current terminal.
    --debug-tty TTY              Enable debug, write output to the specified TTY (e.g., /dev/ttys001).
    --debug-tty .                Enable debug, write output to the TTY path read from the '~/.debug.tty' file

Environment Variables

    BW_CLIENTID                  Bitwarden API key.
    BW_CLIENTSECRET              Bitwarden API key secret.
    RAYVN_PROMPT_TIMEOUT         Default prompt timeout seconds (default: 30).
    WARDN_BACKUP_DIR             Default backup destination directory.
    WARDN_BACKUP_PREFIX          Default backup file name prefix.
```

## Restore Without Installing

The `restore` package contains only what is needed to restore a backup, and can be run without installing anything
other than [Nix](https://nixos.org/download/) (and, on macOS, the Bitwarden CLI, `bw`):

```bash
nix run github:phoggy/wardn#restore -- restore BACKUP_FILE -i KEY_FILE
```
