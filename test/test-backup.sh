#!/usr/bin/env bash

main() {
    init "$@"

    testBackupRoundTrip
    testBackupManifest
    testExtractReportsServer
    testBackupTimeZone
    testBackupRejectsMixedRecipients
    testBackupIgnoresDuplicateRecipients
    testBackupIncludesFiles
    testBackupFailsOnForeignInclude
    testLegacyBackupRestores
    testIsLegacyVaultBackup
    testExtractWithWrongKeyFails
    testDownloadVaultAttachments
    testDownloadVaultAttachmentsSkipsFailures

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
    assertFileDoesNotExist "${backup}.pub"
    [[ ${backup} == "${backupDir}"/test-backup-*_"${ date '+%Z'; }".valt ]] || fail "backup name must use the local time zone: ${backup}"
    assertFalse "a new backup must not be legacy" isLegacyVaultBackup "${backup}"

    local restoreDir; restoreDir="${ makeTempDir; }"
    extractVaultBackup -i "${keyFile}" -o "${restoreDir}" "${backup}" > /dev/null 2>&1 || fail "extract failed"
    assertVaultRestored "${restoreDir}"
}

# A backup's manifest says to restore it with wardn, with the Nix way pinned to a release and extracting discouraged

captureManifest() { cp "$1" "${capturedManifest}"; return 1; }

testBackupManifest() {
    local vaultDir; newVaultDir vaultDir
    local backup; backup="${ newVaultBackup -i "${keyFile}" -R "${pubFile}" -n manifest -u https://vault.bitwarden.eu \
        -o "${ makeTempDir; }" "${vaultDir}"; }"
    declare -g capturedManifest; capturedManifest="${ makeTempDir; }/manifest.json"
    extractSecureArchive -i "${keyFile}" -o "${ makeTempDir; }" --manifest-handler captureManifest "${backup}" || fail
    assertFile "${capturedManifest}"
    assertEqual 'wardn vault backup' "${ jq -r .kind "${capturedManifest}"; }"
    assertEqual 'discouraged' "${ jq -r .extract "${capturedManifest}"; }"
    assertEqual 'restore {archive} -i {identity} -u https://vault.bitwarden.eu' \
        "${ jq -r '.restore.args | join(" ")' "${capturedManifest}"; }" "the restore must use the server backed up from"
    assertEqual 'https://vault.bitwarden.eu' "${ jq -r .bitwardenServer "${capturedManifest}"; }"
    [[ ${ jq -r .restore.nix "${capturedManifest}"; } =~ ^github:phoggy/wardn/v[0-9.]+#restore$ ]] ||
        fail "the Nix way must be pinned to a release: ${ jq -r .restore.nix "${capturedManifest}"; }"
    assertEqual 'rayvn-central/tap/wardn' "${ jq -r .restore.brew "${capturedManifest}"; }"
}

# Extracting a backup reports the server it was made from, or nothing for a backup that does not say

testExtractReportsServer() {
    local vaultDir; newVaultDir vaultDir
    local dir; dir="${ makeTempDir; }"
    local withServer; withServer="${ newVaultBackup -i "${keyFile}" -R "${pubFile}" -n eu -u https://vault.bitwarden.eu \
        -o "${dir}" "${vaultDir}"; }"
    local without; without="${ newVaultBackup -i "${keyFile}" -R "${pubFile}" -n none -o "${dir}" "${vaultDir}"; }"
    local server
    extractVaultBackup -i "${keyFile}" -o "${ makeTempDir; }" -s server "${withServer}" || fail
    assertEqual 'https://vault.bitwarden.eu' "${server}"
    local out; out="${ makeTempDir; }"
    extractVaultBackup -i "${keyFile}" -o "${out}" -s server "${without}" || fail
    assertEqual '' "${server}"
    assertVaultRestored "${out}"
}

testBackupTimeZone() {
    local vaultDir; newVaultDir vaultDir
    local backupDir; backupDir="${ makeTempDir; }"
    local backup; backup="${ newVaultBackup -i "${keyFile}" -R "${pubFile}" -n test-backup -z UTC -o "${backupDir}" "${vaultDir}"; }"
    [[ ${backup} == "${backupDir}"/test-backup-*_UTC.valt ]] || fail "-z UTC must be used: ${backup}"
}

testBackupRejectsMixedRecipients() {
    local vaultDir; newVaultDir vaultDir
    local backupDir; backupDir="${ makeTempDir; }"
    age-keygen -o "${backupDir}/classic.txt" 2> /dev/null || fail
    local classic; classic="${ age-keygen -y "${backupDir}/classic.txt"; }"
    local output; output="${ ( newVaultBackup -i "${keyFile}" -R "${pubFile}" -r "${classic}" -n test-backup -o "${backupDir}" "${vaultDir}" ) 2>&1; }"
    assertNotEqual 0 $? "mixing post-quantum and classic recipients must fail"
    assertContains "Cannot encrypt to both post-quantum keys" "${output}"
}

testBackupIgnoresDuplicateRecipients() {
    local vaultDir; newVaultDir vaultDir
    local backupDir; backupDir="${ makeTempDir; }"
    local backup; backup="${ newVaultBackup -i "${keyFile}" -R "${pubFile}" -R "${pubFile}" -n test-backup -o "${backupDir}" "${vaultDir}" 2>&1; }"
    assertEqual 0 $? "a duplicate recipient must be ignored: ${backup}"
    assertFile "${backup}"
}

# A backup written the way wardn did before it used valt archives: a gzipped tar of a named directory, encrypted with age.

# Writes DIR/NAME.age, encrypted to your key and signed with the given key, as valt encrypt does.

newIncludeFile() {
    local dir="$1" name="$2" signingKey="$3"
    echo "secret ${name}" > "${dir}/${name}"
    encrypt "${dir}/${name}" -R "${pubFile}" -o "${dir}/${name}.age" || fail
    signFile "${signingKey}" "${dir}/${name}.age" || fail
    rm "${dir}/${name}"
}

# Files given with --include are in the restored backup's included/, still encrypted

testBackupIncludesFiles() {
    local vaultDir; newVaultDir vaultDir
    local includeDir; includeDir="${ makeTempDir; }"
    newIncludeFile "${includeDir}" tokens.2fas "${keyFile}"
    local backupDir; backupDir="${ makeTempDir; }"
    local backup; backup="${ newVaultBackup -i "${keyFile}" -R "${pubFile}" --include "${includeDir}" \
        --include-max-age 90 -n included -o "${backupDir}" "${vaultDir}" 2> /dev/null; }" || fail "backup failed"

    local restoreDir; restoreDir="${ makeTempDir; }"
    extractVaultBackup -i "${keyFile}" -o "${restoreDir}" "${backup}" > /dev/null 2>&1 || fail "extract failed"
    assertVaultRestored "${restoreDir}"
    assertFile "${restoreDir}/included/tokens.2fas.age.minisig"
    assertEqual 'secret tokens.2fas' "${ decrypt -i "${keyFile}" "${restoreDir}/included/tokens.2fas.age"; }"
}

# A file signed by another key fails the backup, rather than being left out

testBackupFailsOnForeignInclude() {
    local vaultDir; newVaultDir vaultDir
    local includeDir; includeDir="${ makeTempDir; }"
    newIncludeFile "${includeDir}" forged.txt "${otherKeyFile}"
    local output; output="${ ( newVaultBackup -i "${keyFile}" -R "${pubFile}" --include "${includeDir}" -n forged \
        -o "${ makeTempDir; }" "${vaultDir}" > /dev/null ) 2>&1; }" && fail "the backup must fail"
    assertContains 'is not signed by this key' "${output}"
}

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
    local errors; errors="${ isLegacyVaultBackup "${dir}/armored.age" 2>&1 > /dev/null; }"
    assertEqual '' "${errors}" "the check must not write errors"
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

# A stand-in for 'bw get attachment ID --itemid ITEM --output FILE' that writes "ITEM/ID" to FILE, or fails for the
# attachment id in failAttachmentId (a local of the calling test).

bw() {
    [[ $1 == get && $2 == attachment ]] || fail "unexpected bw command: $*"
    local attachmentId="$3" itemId='' output=''
    shift 3
    while (( $# )); do
        case "$1" in
            --itemid) itemId="$2"; shift ;;
            --output) output="$2"; shift ;;
        esac
        shift
    done
    [[ ${attachmentId} == "${failAttachmentId}" ]] && return 1
    echo "${itemId}/${attachmentId}" > "${output}"
}

# Items as 'bw list items' outputs them: attachments under item ids, an item with no attachments, an item in an
# organization and an item in the trash (both skipped, as 'bw export' leaves them out).

newVaultItems() {
    local -n itemsRef=$1
    itemsRef='[
        {"id": "item-1", "name": "🔑 backup keys", "attachments": [
            {"id": "a1", "fileName": "backup.profile"},
            {"id": "a2", "fileName": "my.backup.key"},
            {"id": "a3", "fileName": "my.backup.key"},
            {"id": "a4", "fileName": ".hidden"}]},
        {"id": "item-2", "name": "login"},
        {"id": "item-3", "name": "notes", "attachments": [{"id": "a5", "fileName": "a/b.txt"}]},
        {"id": "item-4", "name": "shared", "organizationId": "org-1", "attachments": [{"id": "a6", "fileName": "s.txt"}]},
        {"id": "item-5", "name": "deleted", "deletedDate": "2026-01-01T00:00:00Z", "attachments": [{"id": "a7", "fileName": "d.txt"}]}
    ]'
}

testDownloadVaultAttachments() {
    local items; newVaultItems items
    local dir; dir="${ makeTempDir; }"
    local count
    local failAttachmentId=''
    downloadVaultAttachments items "${dir}" count
    assertEqual 5 "${count}"
    assertEqual 'item-1/a1' "${ cat "${dir}/item-1/backup.profile"; }"
    assertEqual 'item-1/a2' "${ cat "${dir}/item-1/my.backup.key"; }"
    assertEqual 'item-1/a3' "${ cat "${dir}/item-1/my.backup_2.key"; }" "a repeated name must get a suffix"
    assertEqual 'item-1/a4' "${ cat "${dir}/item-1/.hidden"; }"
    assertEqual 'item-3/a5' "${ cat "${dir}/item-3/a_b.txt"; }" "a slash in a name must not make a directory"
    assertFileDoesNotExist "${dir}/item-2"
    assertFileDoesNotExist "${dir}/item-4"
    assertFileDoesNotExist "${dir}/item-5"
}

testDownloadVaultAttachmentsSkipsFailures() {
    local items; newVaultItems items
    local dir; dir="${ makeTempDir; }"
    local count
    local failAttachmentId='a2'
    downloadVaultAttachments items "${dir}" count
    assertEqual 4 "${count}"
    assertEqual 'item-1/a3' "${ cat "${dir}/item-1/my.backup.key"; }"
    assertFileDoesNotExist "${dir}/item-1/my.backup_2.key"
}

source rayvn.up 'rayvn/test' 'valt/keys' 'wardn/backup'
main "$@"
