# wardn

@~/.config/rayvn/claude-rayvn.md

The import above loads the rayvn guide for Claude Code, which rayvn generates. If it is missing, run
`rayvn index --claude` to create it.

## About wardn

wardn backs up Bitwarden vaults (using the Bitwarden CLI, `bw`) as valt secure archives, and restores them.

- Archive creation and extraction are in `lib/backup.sh` (`wardn/backup`), which wraps `valt/archive` and can be tested
  without a Bitwarden login. Restore also accepts legacy backups (age encrypted tar files), detected by their age header.
- Backup and restore need a valt key (`-i`, default `WARDN_IDENTITY` or valt's `valt.key`).
