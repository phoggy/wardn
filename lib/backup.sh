#!/usr/bin/env bash

# Vault backup archives.
# Use via: require 'wardn/backup'

# ◇ Create a vault backup: a valt secure archive (signed and encrypted) of the contents of a directory. The archive file
#   path is written to standard output. No public companion (.pub) is created: the backup is restored and verified with
#   your own key. Its manifest says it is a wardn vault backup, to be restored with wardn rather than extracted, so that
#   valt decrypt offers to restore it with wardn: installed, with Nix (the wardn release current now) or with Homebrew.
#   The Bitwarden server it was made from is recorded too, so that it is restored to the same one by default.
#
# · USAGE
#
#   newVaultBackup -i PATH (-r RECIPIENT | -R PATH)... -n NAME [-z ZONE] [-u URL] -o DIR SOURCE
#
#   -i, --identity PATH        The valt key file used to sign the backup.
#   -r, --recipient RECIPIENT  Encrypt to the specified RECIPIENT (age public key). Can be repeated.
#   -R, --recipient-file PATH  Encrypt to the recipients in PATH, e.g. a valt .pub file. Can be repeated.
#   -n, --name NAME            The backup file name prefix; a timestamp is appended.
#   -z, --zone ZONE            The time zone for the timestamp: 'local', 'UTC' or a name such as 'America/Los_Angeles'
#                              (default: local).
#   -u, --url URL              The Bitwarden server the vault was exported from, e.g. https://vault.bitwarden.eu.
#   -o, --output-dir DIR       The directory to write the backup to.
#   SOURCE (dir)               The directory whose contents are backed up.

newVaultBackup() {
    local -a archiveArgs=() # newSecureArchive's own defaults apply, e.g. the local time zone
    local sourceDir='' serverUrl=''
    while (( $# )); do
        case "$1" in
            -u | --url) shift; serverUrl="$1" ;;
            -i | --identity | -r | --recipient | -R | --recipient-file | -n | --name | -z | --zone | -o | --output-dir)
                archiveArgs+=("$1" "$2"); shift ;;
            -*) invalidArgs "unknown option: $1" ;;
            *) [[ -z ${sourceDir} ]] || invalidArgs "unexpected argument: $1"; sourceDir="$1" ;;
        esac
        shift
    done
    [[ -n ${sourceDir} ]] || invalidArgs "source directory required"
    assertDirectory "${sourceDir}"
    local manifestFile; manifestFile="${ makeTempFile; }" || fail
    _writeBackupManifest "${manifestFile}" "${serverUrl}"
    newSecureArchive -C "${sourceDir}" . "${archiveArgs[@]}" -m "${manifestFile}" --no-mac-metadata --no-public # exported data has no metadata worth keeping
}

# ◇ Extract a vault backup into a directory. A valt secure archive has both its signatures verified before its contents
#   are extracted; a legacy backup (an age encrypted tar file, as written by wardn before it used valt archives) is
#   decrypted and extracted.
#
# · USAGE
#
#   extractVaultBackup -i PATH -o DIR [-s VAR] BACKUP
#
#   -i, --identity PATH   The private key file: a valt key, or for a legacy backup any age identity file.
#   -o, --output-dir DIR  The existing directory to extract into.
#   -s, --server-var VAR  Name of a variable to set to the Bitwarden server the backup was made from, if it says
#                         (backups made by wardn 0.2.0 and earlier do not), else to ''.
#   BACKUP (file)         The backup file.

extractVaultBackup() {
    local identityFile='' destDir='' backupFile='' serverVar=''
    while (( $# )); do
        case "$1" in
            -s | --server-var) shift; serverVar="$1" ;;
            -i | --identity) shift; identityFile="$1" ;;
            -o | --output-dir) shift; destDir="$1" ;;
            -*) invalidArgs "unknown option: $1" ;;
            *) [[ -z ${backupFile} ]] || invalidArgs "unexpected argument: $1"; backupFile="$1" ;;
        esac
        shift
    done
    [[ -n ${backupFile} ]] || invalidArgs "backup file required"
    [[ -n ${identityFile} ]] || invalidArgs "identity file required"
    [[ -n ${destDir} ]] || invalidArgs "output directory required"
    assertFile "${backupFile}"
    assertFile "${identityFile}" "identity file"
    assertDirectory "${destDir}"

    if isLegacyVaultBackup "${backupFile}"; then
        local tarFile="${destDir}/legacy-backup.tar"
        age -d -i "${identityFile}" -o "${tarFile}" "${backupFile}" || fail "could not decrypt ${backupFile}"
        tar -xf "${tarFile}" -C "${destDir}" --strip-components=1 || fail "could not extract ${backupFile}"
        rm -f "${tarFile}"
    else
        declare -g _backupServerUrl=''
        extractSecureArchive -i "${identityFile}" -o "${destDir}" --manifest-handler _readBackupManifest \
            "${backupFile}" || fail
    fi
    if [[ -n ${serverVar} ]]; then
        local -n _evbServerRef="${serverVar}"
        _evbServerRef="${_backupServerUrl:-}"
    fi
    return 0
}

# ◇ Succeeds if the file is a legacy vault backup (an age encrypted tar file) rather than a valt secure archive.
#
# · ARGS
#
#   backupFile (file)  The backup file.

isLegacyVaultBackup() {
    isAgeEncryptedFile "$1"
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'wardn/backup' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_wardn_backup() {
    require 'valt/archive' 'valt/decrypt'
}

# The manifest handler for extracting a backup: notes the Bitwarden server it was made from, and lets it be extracted.

_readBackupManifest() {
    declare -g _backupServerUrl; _backupServerUrl="${ jq -r '.bitwardenServer // empty' "$1"; }"
    return 0
}

# Writes a backup's manifest (see Manifests in valt/archive) to a file: restore with wardn, pinned for Nix to the wardn
# release current now (the latest, if there is none yet), to the Bitwarden server the vault came from if given, and
# extracting discouraged, since the files are the vault's unencrypted export.

_writeBackupManifest() {
    local manifestFile="$1" serverUrl="${2:-}"
    local pkgFile="${wardnHome}/rayvn.pkg"
    local version; version="${ gawk -F"'" '/^projectVersion=/{print $2; exit}' "${pkgFile}"; }"
    local releaseTag; releaseTag="${ valtReleaseTag "${pkgFile}"; }"
    # lint-skip-start (jq program)
    jq -n --arg version "${version}" --arg nix "github:phoggy/wardn${releaseTag:+/${releaseTag}}#restore" \
          --arg server "${serverUrl}" '{
        kind: "wardn vault backup", tool: "wardn", version: $version, extract: "discouraged",
        restore: {args: (["restore", "{archive}", "-i", "{identity}"] + (if $server == "" then [] else ["-u", $server] end)),
                  nix: $nix, brew: "rayvn-central/brew/wardn"}
    } + (if $server == "" then {} else {bitwardenServer: $server} end)' > "${manifestFile}" ||
        fail "could not write ${manifestFile}"
    # lint-skip-end
}
