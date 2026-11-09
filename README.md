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
brew tap rayvn-central/brew
brew install wardn
```

**With Nix:**

```bash
nix profile add github:phoggy/wardn
```

To install a specific version:

```bash
nix profile add github:phoggy/wardn/v0.1.1
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
nix run github:phoggy/wardn#restore
```

## Usage

- **backup** - Export your Bitwarden vault to a [valt](https://github.com/phoggy/valt)
  [secure archive](https://rayvn.ink/valt/api/valt-archive#secure-archives): encrypted with age and signed with your
  valt key. Create a key pair first with `valt keys`.
- **restore** - Verify, decrypt and import a vault backup. Backups made by earlier versions of wardn (age encrypted tar
  files) can still be restored.

Run `wardn --help` for options.
