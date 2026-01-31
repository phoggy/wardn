# wardn

Encrypted [Bitwarden](https://bitwarden.com/) vault backup and restore.

## Prerequisites

Requires [Nix](https://nixos.org/). To install:

```bash
curl -L https://nixos.org/nix/install | sh
```

## Installation

```bash
nix run github:phoggy/wardn
```

All dependencies are declared in the `flake.nix` file in the `runtimeDeps` list. New dependencies must be added there.

### Restore

```bash
nix run github:phoggy/wardn#restore
```

## Usage

- **backup** - Export and encrypt your Bitwarden vault
- **restore** - Decrypt and import a vault backup
