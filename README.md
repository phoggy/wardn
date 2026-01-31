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

### Restore

```bash
nix run github:phoggy/wardn#restore
```

## Usage

- **backup** - Export and encrypt your Bitwarden vault
- **restore** - Decrypt and import a vault backup
