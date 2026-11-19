# wardn

Encrypted [Bitwarden](https://bitwarden.com/) vault backup and restore.

## Prerequisites

Requires [Nix](https://nixos.org/).

**Mac with Apple silicon:** Download and run the [Determinate Nix installer](https://dtr.mn/determinate-nix).

**Mac x86:**

```bash
curl -L https://nixos.org/nix/install | sh
```

**Linux:**

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

All installers create a `/nix` volume and take a few minutes to complete. Answer yes to any
prompts and allow any system dialogs that pop up. Once complete, open a new terminal before
continuing.

If you used the Mac x86 installer, enable flakes:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

## Installation

**With Homebrew:**

```bash
brew tap rayvn-central/tap
brew trust --tap rayvn-central/tap
brew install wardn
```

Homebrew installs formulae from taps other than its own only once you trust them, hence `brew trust`. The tap also has
two of valt's dependencies, [mrld](https://github.com/phoggy/mrld) and [phraze](https://github.com/sts10/phraze).

**With Nix:**

```bash
nix profile add github:phoggy/wardn
```

On macOS, Nix can't build the Bitwarden CLI (`bw`), so install it separately, e.g. with `brew install bitwarden-cli`:
wardn uses the one on your PATH. On Linux, Nix includes it (and Homebrew installs it with wardn everywhere).

To install a specific version:

```bash
nix profile add github:phoggy/wardn/v0.2.0
```

To upgrade to the latest version:

```bash
nix profile upgrade wardn
```

To run without installing:

```bash
nix run github:phoggy/wardn
```

All dependencies are declared in the `flake.nix` file in the `runtimeDeps` list. New dependencies must be added there.

### Restore

```bash
nix run github:phoggy/wardn#restore -- restore BACKUP_FILE -i KEY_FILE
```

This needs only Nix (and, on macOS, the Bitwarden CLI, as above).

## Usage

- **backup** - Export your Bitwarden vault to a [valt](https://github.com/phoggy/valt)
  [secure archive](https://rayvn.ink/valt/api/valt-archive#secure-archives): encrypted with age and signed with your
  valt key. Create a key pair first with `valt keys`.
- **restore** - Verify, decrypt and import a vault backup, into the Bitwarden server it was made from unless `-u` gives
  another. Backups made by earlier versions of wardn (age encrypted tar files) can still be restored.

`valt decrypt BACKUP` recognizes a wardn backup, and offers to restore it with wardn: installed, or with Nix or
Homebrew.

Run `wardn --help` for options.

### Including other files

A backup can also carry other encrypted files, so that everything needed to recover is in one place: for example,
an export of an authenticator app's tokens, which you would not keep in Bitwarden itself.

For example, with [2FAS](https://2fas.com): in the app, export a backup **with a password** (Settings → 2FAS
Backup → Export), using a long random password that you save in your vault. Copy the export to your computer (it is
encrypted, so it never exists unencrypted there), then:

```bash
valt encrypt ~/Downloads/EXPORT.2fas -o ~/Recovery/tokens.2fas.age -f && rm ~/Downloads/EXPORT.2fas
$EDITOR ~/Recovery/tokens.2fas.age.note  # how to recover the tokens: see below
export WARDN_INCLUDE_PATH=~/Recovery     # e.g. in your profile
wardn backup                             # includes ~/Recovery's .age and .valt files
```

Repeat the export whenever you add tokens.

**Say how to recover it.** Whoever restores the backup may not know what an included file is, or what to do with it,
so give each one a note: a text file of the same name plus `.note`, as above. It is included with the file, and
`wardn restore` shows it. For example:

```text
2FAS authenticator tokens: a password-protected export from the 2FAS app. To restore them to a phone:

1. Open this file with the same key as the backup: valt decrypt tokens.2fas.age (gives tokens.2fas)
2. Copy tokens.2fas to the phone, and in 2FAS: Settings → 2FAS Backup → Import.
3. Enter the export password: it is in the restored vault, in the item "2FAS export password".
4. Delete tokens.2fas from the computer and the phone.
```

The note is encrypted in the backup, but should never hold the password itself: say where to find it.

- `WARDN_INCLUDE_PATH` lists files and directories, separated by `:`, whose `.age` and `.valt` files are included;
  `--include PATH` adds more, and `--no-include` ignores the variable for one backup.
- **Each must be signed by, and openable with, your valt key**, or the backup fails. So the key that opens the
  backup opens everything in it, and a file someone else made can't be slipped in. Other recipients are fine.
- They are included still encrypted, and wardn warns about any not modified for 90 days
  (`WARDN_INCLUDE_MAX_AGE_DAYS`): re-export them when they change.
- `wardn restore` saves them, still encrypted, next to the backup (`BACKUP-included/`), and shows each one's note;
  open each with `valt decrypt FILE`.

## Best Practices

A backup holds your whole vault, so it needs the care the vault itself gets. One that includes your 2FA tokens (see
[Including other files](#including-other-files)) holds your second factors as well: that is what makes it a complete
recovery set, opened by your valt key alone, and why these practices matter.

- **Follow valt's [best practices](https://github.com/phoggy/valt#best-practices):** keep backups apart from your paper
  key, treat a paper key with the passphrase written on it as a complete key, keep a copy of the passphrase you can
  reach without Bitwarden, and type it only on a computer you trust.
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
