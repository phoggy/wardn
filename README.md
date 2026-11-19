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

```bash
valt encrypt ~/Downloads/2fas-backup.2fas -o ~/Recovery/2fas.age -f --verify --delete
export WARDN_INCLUDE_PATH=~/Recovery     # e.g. in your profile
wardn backup                             # includes ~/Recovery's .age and .valt files
```

- `WARDN_INCLUDE_PATH` lists files and directories, separated by `:`, whose `.age` and `.valt` files are included;
  `--include PATH` adds more, and `--no-include` ignores the variable for one backup.
- **Each must be signed by, and openable with, your valt key**, or the backup fails. So the key that opens the
  backup opens everything in it, and a file someone else made can't be slipped in. Other recipients are fine.
- They are included still encrypted, and wardn warns about any not modified for 90 days
  (`WARDN_INCLUDE_MAX_AGE_DAYS`): re-export them when they change.
- `wardn restore` saves them, still encrypted, next to the backup (`BACKUP-included/`); open each with
  `valt decrypt FILE`.

A backup that includes your 2FA tokens holds both your passwords and your second factors, protected by your valt
key and its passphrase. That is the point for recovery, but keep backups apart from your paper key, and the
passphrase apart from both.
