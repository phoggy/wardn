---
layout: default
title: "wardn/backup"
parent: API Reference
nav_order: 1
---

# wardn/backup

Vault backup archives.

## Functions

### newVaultBackup()

Create a vault backup: a valt secure archive (signed and encrypted) of the contents of a directory. The archive file
path is written to standard output. No public companion (.pub) is created: the backup is restored and verified with
your own key.


*usage*

`newVaultBackup -i PATH (-r RECIPIENT | -R PATH)... -n NAME [-z ZONE] -o DIR SOURCE`
{: .usage-signature}

| | |
|---|---|
| `-i, --identity PATH` | The valt key file used to sign the backup. |
| `-r, --recipient RECIPIENT` | Encrypt to the specified RECIPIENT (age public key). Can be repeated. |
| `-R, --recipient-file PATH` | Encrypt to the recipients in PATH, e.g. a valt .pub file. Can be repeated. |
| `-n, --name NAME` | The backup file name prefix; a timestamp is appended. |
| `-z, --zone ZONE` | The time zone for the timestamp: 'local', 'UTC' or a name such as 'America/Los_Angeles' (default: local). |
| `-o, --output-dir DIR` | The directory to write the backup to. |
| `SOURCE` *(dir)* | The directory whose contents are backed up. |
{: .usage-table}

### extractVaultBackup()

Extract a vault backup into a directory. A valt secure archive has both its signatures verified before its contents
are extracted; a legacy backup (an age encrypted tar file, as written by wardn before it used valt archives) is
decrypted and extracted.


*usage*

`extractVaultBackup -i PATH -o DIR BACKUP`
{: .usage-signature}

| | |
|---|---|
| `-i, --identity PATH` | The private key file: a valt key, or for a legacy backup any age identity file. |
| `-o, --output-dir DIR` | The existing directory to extract into. |
| `BACKUP` *(file)* | The backup file. |
{: .usage-table}

### isLegacyVaultBackup()

Succeeds if the file is a legacy vault backup (an age encrypted tar file) rather than a valt secure archive.


*args*

| | |
|---|---|
| `backupFile` *(file)* | The backup file. |
{: .args-table}

