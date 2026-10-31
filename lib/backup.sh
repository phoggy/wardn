#!/usr/bin/env bash

# Vault backup archives.
# Use via: require 'wardn/backup'

# ◇ Create a vault backup: a valt secure archive (signed and encrypted) of the contents of a directory. The archive file
#   path is written to standard output; a public companion (same path plus ".pub") is also created.
#
# · USAGE
#
#   newVaultBackup -i PATH (-r RECIPIENT | -R PATH)... -n NAME -o DIR SOURCE
#
#   -i, --identity PATH        The valt key file used to sign the backup.
#   -r, --recipient RECIPIENT  Encrypt to the specified RECIPIENT (age public key). Can be repeated.
#   -R, --recipient-file PATH  Encrypt to the recipients in PATH, e.g. a valt .pub file. Can be repeated.
#   -n, --name NAME            The backup file name prefix; a timestamp is appended.
#   -o, --output-dir DIR       The directory to write the backup to.
#   SOURCE (dir)               The directory whose contents are backed up.

newVaultBackup() {
    local -a archiveArgs=()
    local sourceDir=''
    while (( $# )); do
        case "$1" in
            -i | --identity | -r | --recipient | -R | --recipient-file | -n | --name | -o | --output-dir)
                archiveArgs+=("$1" "$2"); shift ;;
            -*) invalidArgs "unknown option: $1" ;;
            *) [[ -z ${sourceDir} ]] || invalidArgs "unexpected argument: $1"; sourceDir="$1" ;;
        esac
        shift
    done
    [[ -n ${sourceDir} ]] || invalidArgs "source directory required"
    assertDirectory "${sourceDir}"
    newSecureArchive -C "${sourceDir}" . "${archiveArgs[@]}"
}

# ◇ Extract a vault backup into a directory. A valt secure archive has both its signatures verified before its contents
#   are extracted; a legacy backup (an age encrypted tar file, as written by wardn before it used valt archives) is
#   decrypted and extracted.
#
# · USAGE
#
#   extractVaultBackup -i PATH -o DIR BACKUP
#
#   -i, --identity PATH   The private key file: a valt key, or for a legacy backup any age identity file.
#   -o, --output-dir DIR  The existing directory to extract into.
#   BACKUP (file)         The backup file.

extractVaultBackup() {
    local identityFile='' destDir='' backupFile=''
    while (( $# )); do
        case "$1" in
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
        extractSecureArchive -i "${identityFile}" -o "${destDir}" "${backupFile}" || fail
    fi
}

# ◇ Succeeds if the file is a legacy vault backup (an age encrypted tar file) rather than a valt secure archive.
#
# · ARGS
#
#   backupFile (file)  The backup file.

isLegacyVaultBackup() {
    head -c 64 "$1" | LC_ALL=C grep -qa -e '^age-encryption\.org/' -e '^-----BEGIN AGE ENCRYPTED FILE-----'
}

PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'wardn/backup' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_wardn_backup() {
    require 'valt/archive'
}
