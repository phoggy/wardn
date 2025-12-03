#!/usr/bin/env bash

# Library supporting generation of bitwarden-security-readiness-kit pdf.
# Intended for use via: require 'wardn/security-kit'

require 'rayvn/core'

# TODO: This is just a placeholder/test for now. How do get and securely keep
#       a filled out version that we can update as needed?

generateSecurityKit() {
    _initSecurityKit
    local json="${securityKitJson}"
    local jsonFile="${ tempDirPath form.json; }"
    local newPdfFile="bitwarden-security-kit.pdf"

    _setSecurityKitFieldValue json 'last-updated-date' "${ date '+%B %-d, %Y'; }"
    _setSecurityKitFieldValue json 'bw-vault-url' "${vaultUrl}"   # TODO assume, or pass in?

    _getSecurityKitFieldValue json 'last-updated-date'
    _getSecurityKitFieldValue json 'bw-vault-url'

    echo "${json}" > "${jsonFile}"
    pdfcpu form fill "${securityKitPdfFile}" "${jsonFile}" "${newPdfFile}"  || fail
    open "${newPdfFile}"
}


PRIVATE_CODE="--+-+-----+-++(-++(---++++(---+( ⚠️ BEGIN 'wardn/security-kit' PRIVATE ⚠️ )+---)++++---)++-)++-+------+-+--"

_init_wardn_security-kit() {
    require 'rayvn/core'
}

_initSecurityKit() {
    if [[ ! -v securityKitPdfFile ]]; then
        local basePath="${wardnHome}/etc/bw-security-kit"

        declare -gr securityKitPdfFile="${basePath}.pdf"
        declare -gr securityKitJson="${ < "${basePath}.json"; }"
    fi
}

_getSecurityKitFieldValue() {
    local -n jsonVar="${1}"
    local fieldKey="${2}"
    local fieldId="${security_kit_field_ids[${fieldKey}]}"
    [[ -z ${fieldId} ]] && fail "Unknown field key: ${fieldKey}"

    local result
    result="${ jq -er '
        .forms[0].textfield[]?, .forms[0].checkbox[]?
        | select(.id == "'"${fieldId}"'")
        | .value' <<< "${jsonVar}"; }" || fail "Field ID ${fieldId} (${fieldKey}) not found in JSON"

    echo "${result}"
}

_setSecurityKitFieldValue() {
    local -n jsonVar="${1}"
    local fieldKey="${2}"
    local newValue="${3}"
    local fieldId="${security_kit_field_ids[${fieldKey}]}"
    [[ -z ${fieldId} ]] && fail "Unknown field key: ${fieldKey}"

    # Check that the ID exists as a string match
    jq -e --arg id "${fieldId}" '
        .forms[0].textfield[]?, .forms[0].checkbox[]?
        | select(.id == $id)' <<< "${jsonVar}" > /dev/null \
        || fail "Field ID ${fieldId} (${fieldKey}) not found in JSON"

    jsonVar="${ jq \
        --arg id "${fieldId}" \
        --argjson isBool "${ [[ ${newValue} == true || ${newValue} == false ]] && echo true || echo false; }" \
        --arg value "${newValue}" '
        (.forms[0].textfield[]?, .forms[0].checkbox[]?
        | select(.id == $id)
        | .value) = (
            if $isBool then ($value | test("true")) else $value end
        )' <<< "${jsonVar}"; }" || fail "Failed to update field '${fieldKey}'"
}

# Name to id mapping. Ugh. Would be far less fragile if the field names corresponded
# so we could eliminate this mapping! TODO ask u/Ryan_BW as u/djasonpenney suggested.
declare -grA security_kit_field_ids=(

    [last-updated-date]='20'

    [bw-vault-url]='25'
    [bw-login-email]='29'
    [bw-login-password]='33'
    [bw-2fa-login-recovery-code]='37'

    [email-url]='27'
    [email-address]='31'
    [email-password]='35'
    [email-2fa-recovery-code]='39'

    [2fa-email-checkbox]='43'
    [2fa-email-details]='41'

    [2fa-application-checkbox]='47'
    [2fa-applicaton-details]='61'

    [2fa-hw-passkey-checkbox]='50'
    [2fa-hw-passkey-details]='63'

    [2fa-yubico-otp-checkbox]='53'
    [2fa-yubico-otp-details]='65'

    [2fa-duo-checkbox]='56'
    [2fa-duo-details]='67'

    [notes]='38'
)
