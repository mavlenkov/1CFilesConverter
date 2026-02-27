#!/usr/bin/env bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

source "$(dirname "$(readlink -f "$0")")/common.sh"

init_common "Validate 1C configuration, extension, external data processors & reports using 1C:EDT (using ring tool)"

: "${V8_VERSION:=8.3.23.2040}"
: "${V8_TEMP:=/tmp/1c}"

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SCRIPT_NAME="$(basename "$0" .sh)"

LOCAL_TEMP="${V8_TEMP}/${SCRIPT_NAME}"
if [[ -z "${VALIDATE_PATH:-}" ]]; then
    VALIDATE_PATH="${LOCAL_TEMP}/tmp_edt"
fi
WS_PATH="${LOCAL_TEMP}/edt_ws"

# Parse arguments
V8_SRC_PATH="${V8_SRC_PATH:-${1:-}}"
REPORT_FILE="${2:-}"
if [[ -n "${REPORT_FILE}" ]]; then
    REPORT_FILE_PATH="$(dirname "${REPORT_FILE}")"
fi
EXT_NAME="${3:-}"

# Validate
if [[ -z "${V8_SRC_PATH}" ]]; then
    echo '[ERROR] Missed parameter 1 - "path to 1C configuration, extension, data processors or reports (binary (*.cf, *.cfe, *.epf, *.erf), 1C:Designer XML format or 1C:EDT format)"'
    ERROR_CODE=1
fi
if [[ -z "${REPORT_FILE}" ]]; then
    echo '[ERROR] Missed parameter 2 - "path to validation report file"'
    ERROR_CODE=1
fi
if [[ "${ERROR_CODE}" -ne 0 ]]; then
    echo "======"
    echo "[ERROR] Input parameters error. Expected:"
    echo "    %1 - path to 1C configuration, extension, data processors or reports (binary (*.cf, *.cfe, *.epf, *.erf), 1C:Designer XML format or 1C:EDT project)"
    echo "    %2 - path to validation report file"
    echo ""
    cleanup_and_exit
fi

echo "[INFO] Clear temporary files..."
[[ -d "${LOCAL_TEMP}" ]] && rm -rf "${LOCAL_TEMP}"
mkdir -p "${LOCAL_TEMP}"
[[ -n "${REPORT_FILE_PATH:-}" ]] && [[ ! -d "${REPORT_FILE_PATH}" ]] && mkdir -p "${REPORT_FILE_PATH}"

echo "[INFO] Prepare project for validation..."

# Determine source type and convert to EDT if needed
if [[ -d "${V8_SRC_PATH}/DT-INF" ]]; then
    VALIDATE_PATH="${V8_SRC_PATH}"
elif [[ "${V8_SRC_PATH: -3}" == ".cf" ]] || [[ "${V8_SRC_PATH: -3}" == ".CF" ]]; then
    mkdir -p "${VALIDATE_PATH}"
    "${SCRIPT_DIR}/conf2edt.sh" "${V8_SRC_PATH}" "${VALIDATE_PATH}"
elif [[ "${V8_SRC_PATH: -4}" == ".cfe" ]] || [[ "${V8_SRC_PATH: -4}" == ".CFE" ]]; then
    mkdir -p "${VALIDATE_PATH}"
    "${SCRIPT_DIR}/ext2edt.sh" "${V8_SRC_PATH}" "${VALIDATE_PATH}" "${EXT_NAME}"
elif [[ -f "${V8_SRC_PATH}/Configuration.xml" ]]; then
    mkdir -p "${VALIDATE_PATH}"
    if grep -qi "<objectBelonging>" "${V8_SRC_PATH}/Configuration.xml" 2>/dev/null; then
        "${SCRIPT_DIR}/ext2edt.sh" "${V8_SRC_PATH}" "${VALIDATE_PATH}"
    else
        "${SCRIPT_DIR}/conf2edt.sh" "${V8_SRC_PATH}" "${VALIDATE_PATH}"
    fi
else
    local_prefix="${V8_SRC_PATH:0:2}"
    local_prefix_lc="${local_prefix,,}"

    if [[ "${local_prefix_lc}" == "/f" ]]; then
        mkdir -p "${VALIDATE_PATH}"
        "${SCRIPT_DIR}/conf2edt.sh" "${V8_SRC_PATH}" "${VALIDATE_PATH}"
    elif [[ "${local_prefix_lc}" == "/s" ]]; then
        mkdir -p "${VALIDATE_PATH}"
        "${SCRIPT_DIR}/conf2edt.sh" "${V8_SRC_PATH}" "${VALIDATE_PATH}"
    elif is_file_ib "${V8_SRC_PATH}"; then
        mkdir -p "${VALIDATE_PATH}"
        "${SCRIPT_DIR}/conf2edt.sh" "${V8_SRC_PATH}" "${VALIDATE_PATH}"
    else
        # Check for dp/report files
        local_found=0
        for f in "${V8_SRC_PATH}"/*.epf "${V8_SRC_PATH}"/*.erf "${V8_SRC_PATH}"/*.xml; do
            if [[ -f "${f}" ]]; then
                local_found=1
                break
            fi
        done
        if [[ "${local_found}" == "0" ]] && [[ -d "${V8_SRC_PATH}/ExternalDataProcessors" ]]; then
            for f in "${V8_SRC_PATH}/ExternalDataProcessors"/*.xml; do
                if [[ -f "${f}" ]]; then
                    local_found=1
                    break
                fi
            done
        fi
        if [[ "${local_found}" == "0" ]] && [[ -d "${V8_SRC_PATH}/ExternalReports" ]]; then
            for f in "${V8_SRC_PATH}/ExternalReports"/*.xml; do
                if [[ -f "${f}" ]]; then
                    local_found=1
                    break
                fi
            done
        fi
        if [[ "${local_found}" == "1" ]]; then
            mkdir -p "${VALIDATE_PATH}"
            "${SCRIPT_DIR}/dp2edt.sh" "${V8_SRC_PATH}" "${VALIDATE_PATH}"
        else
            echo "[ERROR] Error cheking type of configuration \"${BASE_CONFIG:-}\"!"
            echo "Infobase, configuration file (*.cf), configuration extension file (*.cfe), folder contains external data processors & reports in binary or XML format, 1C:Designer XML or 1C:EDT project expected."
            ERROR_CODE=1
            cleanup_and_exit
        fi
    fi
fi

# --- validate ---
echo "[INFO] Run validation in \"${VALIDATE_PATH}\"..."

mkdir -p "${WS_PATH}"

run_edt_validate "${VALIDATE_PATH}" "${REPORT_FILE}"
ERROR_CODE=$?

cleanup_and_exit
