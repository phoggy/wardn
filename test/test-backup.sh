#!/usr/bin/env bash

main() {
    init "$@"

    testBackupRoundTrip
    testLegacyBackupRestores
    testIsLegacyVaultBackup
    testExtractWithWrongKeyFails

    return 0
}

init() {
    while (( $# )); do
        case "$1" in
            --debug*) setDebug "$@"; shift $? ;;
        esac
        shift
    done

    declare -gx rayvnTest_ValtKeyPassphrase='wardn-test-passphrase-12345'
    skipKeyPassphraseAdvice=1
    allowWeakKeyPassphrase=1

    declare -g keyDir pubFile keyFile otherPubFile otherKeyFile
    keyDir="${ makeTempDir; }"
    newValtKeys 'test' "${keyDir}" pubFile keyFile
    newValtKeys 'other' "${keyDir}" otherPubFile otherKeyFile
}

# Creates a fake exported vault (vault.json and an attachment) in a new directory, setting the named var to its path.

newVaultDir() {
    local -n vaultDirRef=$1
    local dir; dir="${ makeTempDir; }"
    echo '{"items":[{"id":"1","name":"login"}]}' > "${dir}/vault.json"
    mkdir -p "${dir}/attachments/item-1" || fail
    echo 'attached' > "${dir}/attachments/item-1/note.txt"
    vaultDirRef="${dir}"
}

assertVaultRestored() {
    local dir="$1"
    assertEqual '{"items":[{"id":"1","name":"login"}]}' "${ cat "${dir}/vault.json"; }"
    assertEqual 'attached' "${ cat "${dir}/attachments/item-1/note.txt"; }"
}

testBackupRoundTrip() {
    local vaultDir; newVaultDir vaultDir
    local backupDir; backupDir="${ makeTempDir; }"
    local backup; backup="${ newVaultBackup -i "${keyFile}" -R "${pubFile}" -n test-backup -o "${backupDir}" "${vaultDir}"; }"
    assertFile "${backup}"
    assertFile "${backup}.pub"
    [[ ${backup} == "${backupDir}"/test-backup-*.valt ]] || fail "unexpected backup name: ${backup}"
    assertFalse "a new backup must not be legacy" isLegacyVaultBackup "${backup}"

    local restoreDir; restoreDir="${ makeTempDir; }"
    extractVaultBackup -i "${keyFile}" -o "${restoreDir}" "${backup}" > /dev/null 2>&1 || fail "extract failed"
    assertVaultRestored "${restoreDir}"
}

# A backup written the way wardn did before it used valt archives: a gzipped tar of a named directory, encrypted with age.

testLegacyBackupRestores() {
    local vaultDir; newVaultDir vaultDir
    local legacyDir; legacyDir="${ makeTempDir; }"
    age-keygen -o "${legacyDir}/identity.txt" 2> /dev/null || fail
    local recipient; recipient="${ age-keygen -y "${legacyDir}/identity.txt"; }"
    mv "${vaultDir}" "${legacyDir}/me-backup-2026" || fail
    ( cd "${legacyDir}" && tar cz me-backup-2026 | age -r "${recipient}" > me-backup-2026.valt ) || fail

    assertTrue "a legacy backup must be detected" isLegacyVaultBackup "${legacyDir}/me-backup-2026.valt"
    local restoreDir; restoreDir="${ makeTempDir; }"
    extractVaultBackup -i "${legacyDir}/identity.txt" -o "${restoreDir}" "${legacyDir}/me-backup-2026.valt" || fail "legacy extract failed"
    assertVaultRestored "${restoreDir}"
    assertFileDoesNotExist "${restoreDir}/legacy-backup.tar"
}

testIsLegacyVaultBackup() {
    local dir; dir="${ makeTempDir; }"
    age-keygen -o "${dir}/identity.txt" 2> /dev/null || fail
    echo 'secret' | age -a -r "${ age-keygen -y "${dir}/identity.txt"; }" > "${dir}/armored.age" || fail
    assertTrue "an armored age file must be detected as legacy" isLegacyVaultBackup "${dir}/armored.age"
    echo 'plain text' > "${dir}/plain.txt"
    assertFalse "a plain file must not be legacy" isLegacyVaultBackup "${dir}/plain.txt"
}

testExtractWithWrongKeyFails() {
    local vaultDir; newVaultDir vaultDir
    local backupDir; backupDir="${ makeTempDir; }"
    local backup; backup="${ newVaultBackup -i "${keyFile}" -R "${pubFile}" -n test-backup -o "${backupDir}" "${vaultDir}"; }"
    local restoreDir; restoreDir="${ makeTempDir; }"
    ( extractVaultBackup -i "${otherKeyFile}" -o "${restoreDir}" "${backup}" ) > /dev/null 2>&1 && fail "extract with another key must fail"
    assertFileDoesNotExist "${restoreDir}/vault.json"
}

source rayvn.up 'rayvn/test' 'valt/keys' 'wardn/backup'
main "$@"
