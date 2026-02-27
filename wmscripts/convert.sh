#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONVERT_VERSION="UNKNOWN"
if [[ -f "${SCRIPT_DIR}/../VERSION" ]]; then
    CONVERT_VERSION="$(cat "${SCRIPT_DIR}/../VERSION")"
fi
echo "1C files converter v.${CONVERT_VERSION}"
echo "==="
echo "[INFO] Running conversion of files"

ERROR_CODE=0

CONVERT_SCRIPT="$1"
if [[ -z "${CONVERT_SCRIPT}" ]]; then
    echo "[ERROR] Missed parameter 1 - \"path to conversion script file (could be 1C converter script name or full path to script file)\""
    ERROR_CODE=1
fi
if [[ -n "${CONVERT_SCRIPT}" && ! -f "${CONVERT_SCRIPT}" ]]; then
    CONVERT_SCRIPT_PATH="$(cd "${SCRIPT_DIR}/../scripts" 2>/dev/null && pwd)"
    if [[ -n "${CONVERT_SCRIPT_PATH}" ]]; then
        echo "[WARN] Script file \"${CONVERT_SCRIPT}\" doesn't exist (parameter 1). Trying to find in \"${CONVERT_SCRIPT_PATH}\" directory."
        CONVERT_SCRIPT="${CONVERT_SCRIPT_PATH}/${CONVERT_SCRIPT}.sh"
    fi
fi
if [[ -n "${CONVERT_SCRIPT}" && ! -f "${CONVERT_SCRIPT}" ]]; then
    echo "[ERROR] Script file \"${CONVERT_SCRIPT}\" doesn't exist (parameter 1)."
    ERROR_CODE=1
fi

CONVERT_SRC_PATH="$2"
if [[ -z "${CONVERT_SRC_PATH}" ]]; then
    echo "[ERROR] Missed parameter 2 - \"path to convertion source\""
    ERROR_CODE=1
elif [[ ! -e "${CONVERT_SRC_PATH}" ]]; then
    echo "[ERROR] Path \"${CONVERT_SRC_PATH}\" doesn't exist (parameter 2)."
    ERROR_CODE=1
fi

CONVERT_DST_PATH="$3"
if [[ -z "${CONVERT_DST_PATH}" ]]; then
    echo "[ERROR] Missed parameter 3 - \"output path to save conversion results\""
    ERROR_CODE=1
fi
if [[ -n "${CONVERT_DST_PATH}" && ! -d "${CONVERT_DST_PATH}" ]]; then
    mkdir -p "${CONVERT_DST_PATH}"
fi

if [[ ${ERROR_CODE} -ne 0 ]]; then
    exit ${ERROR_CODE}
fi

V8_DP_CLEAN_DST=0
export V8_DP_CLEAN_DST

while IFS= read -r CURRENT_FILE; do
    [[ -z "${CURRENT_FILE}" ]] && continue
    RELATIVE_PATH="$(dirname "${CURRENT_FILE}")"
    if [[ "${RELATIVE_PATH}" != "." ]]; then
        DST_PATH="${CONVERT_DST_PATH}/${RELATIVE_PATH}"
    else
        DST_PATH="${CONVERT_DST_PATH}"
    fi
    "${CONVERT_SCRIPT}" "${CONVERT_SRC_PATH}/${CURRENT_FILE}" "${DST_PATH}"
done
