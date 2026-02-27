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

init_common "Convert 1C configuration extension to binary format (*.cfe)"
init_convert_tool 1 || cleanup_and_exit
init_temp_paths

# Parse arguments
V8_SRC_PATH="${V8_SRC_PATH:-${1:-}}"
V8_DST_PATH="${V8_DST_PATH:-${2:-}}"
if [[ -n "${V8_DST_PATH}" ]]; then
    V8_DST_FOLDER="$(dirname "${V8_DST_PATH}")"
fi
V8_EXT_NAME="${V8_EXT_NAME:-${3:-}}"

# Validate
if [[ -z "${V8_SRC_PATH}" ]]; then
    echo '[ERROR] Missed parameter 1 - "path to 1C extension source (1C extension binary file (*.cfe), 1C:Designer XML files or 1C:EDT project)"'
    ERROR_CODE=1
else
    if [[ ! -e "${V8_SRC_PATH}" ]]; then
        echo "[ERROR] Path \"${V8_SRC_PATH}\" doesn't exist (parameter 1)."
        ERROR_CODE=1
    fi
fi
if [[ -z "${V8_DST_PATH}" ]]; then
    echo '[ERROR] Missed parameter 2 - "path to 1C infobase"'
    ERROR_CODE=1
fi
if [[ -z "${V8_EXT_NAME}" ]]; then
    echo '[ERROR] Missed parameter 3 - "configuration extension name"'
    ERROR_CODE=1
fi
if [[ "${ERROR_CODE}" -ne 0 ]]; then
    echo "======"
    echo "[ERROR] Input parameters error. Expected:"
    echo "    %1 - path to 1C extension source (1C extension binary file (*.cfe), 1C:Designer XML files or 1C:EDT project)"
    echo "    %2 - path to 1C infobase"
    echo "    %3 - configuration extension name"
    echo ""
    cleanup_and_exit
fi

echo "[INFO] Clear temporary files..."
[[ -d "${LOCAL_TEMP}" ]] && rm -rf "${LOCAL_TEMP}"
mkdir -p "${LOCAL_TEMP}"
[[ -n "${V8_DST_FOLDER:-}" ]] && [[ ! -d "${V8_DST_FOLDER}" ]] && mkdir -p "${V8_DST_FOLDER}"

echo "[INFO] Checking extension ${V8_DST_PATH} destination type..."

# Parse destination infobase
local_prefix="${V8_DST_PATH:0:2}"
local_prefix_lc="${local_prefix,,}"

if [[ "${local_prefix_lc}" == "/f" ]]; then
    IB_PATH="${V8_DST_PATH:2}"
    echo "[INFO] Destination type: File infobase (${IB_PATH})"
    V8_IB_CONNECTION="File=\"${IB_PATH}\";"
elif [[ "${local_prefix_lc}" == "/s" ]]; then
    IB_PATH="${V8_DST_PATH:2}"
    IFS='\\/' read -r V8_IB_SERVER V8_IB_NAME <<< "${IB_PATH}"
    echo "[INFO] Destination type: Server infobase (${V8_IB_SERVER}\\${V8_IB_NAME})"
    IB_PATH="${V8_IB_SERVER}\\${V8_IB_NAME}"
    V8_IB_CONNECTION="Srvr=\"${V8_IB_SERVER}\";Ref=\"${V8_IB_NAME}\";"
    : "${V8_DB_SRV_DBMS:=MSSQLServer}"
else
    IB_PATH="${V8_DST_PATH}"
    if is_file_ib "${IB_PATH}"; then
        echo "[INFO] Destination type: File infobase (${IB_PATH})"
        V8_IB_CONNECTION="File=\"${IB_PATH}\";"
    else
        echo "[ERROR] Error cheking type of destination \"${V8_DST_PATH}\"!"
        echo "Server or file infobase expected."
        ERROR_CODE=1
        cleanup_and_exit
    fi
fi

# --- check_src ---
echo "[INFO] Checking 1C extension source type..."

if [[ -d "${V8_SRC_PATH}/DT-INF" ]] && [[ -f "${V8_SRC_PATH}/src/Configuration/Configuration.mdo" ]]; then
    if grep -qi "<objectBelonging>" "${V8_SRC_PATH}/src/Configuration/Configuration.mdo" 2>/dev/null; then
        echo "[INFO] Source type: 1C:EDT project"
        mkdir -p "${XML_PATH}"
        mkdir -p "${WS_PATH}"

        # --- export_edt ---
        echo "[INFO] Export configuration extension from 1C:EDT format \"${V8_SRC_PATH}\" to 1C:Designer XML format \"${XML_PATH}\"..."
        run_edt_export "${V8_SRC_PATH}" "${XML_PATH}"
        if [[ $? -ne 0 ]]; then
            ERROR_CODE=$?
            cleanup_and_exit
        fi

        # --- export_xml ---
        echo "[INFO] Loading configuration extension from XML-files \"${XML_PATH}\" to infobase \"${IB_PATH}\"..."
        if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
            run_designer "${V8_IB_CONNECTION}" /LoadConfigFromFiles "${XML_PATH}" -Extension "${V8_EXT_NAME}"
            print_designer_log "${V8_DESIGNER_LOG}"
        else
            if [[ -n "${V8_IB_SERVER:-}" ]]; then
                "${IBCMD_TOOL}" infobase config import --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" "${XML_PATH}"
            else
                "${IBCMD_TOOL}" infobase config import --data="${IBCMD_DATA}" --db-path="${IB_PATH}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" "${XML_PATH}"
            fi
        fi
        ERROR_CODE=$?
        if [[ "${ERROR_CODE}" -eq 0 ]]; then
            run_update_db "${V8_IB_CONNECTION}" "${V8_EXT_NAME}"
            ERROR_CODE=$?
        fi
        cleanup_and_exit
    fi
fi

if [[ -f "${V8_SRC_PATH}/Configuration.xml" ]]; then
    if grep -qi "<objectBelonging>" "${V8_SRC_PATH}/Configuration.xml" 2>/dev/null; then
        echo "[INFO] Source type: 1C:Designer XML files"
        XML_PATH="${V8_SRC_PATH}"

        # --- export_xml ---
        echo "[INFO] Loading configuration extension from XML-files \"${XML_PATH}\" to infobase \"${IB_PATH}\"..."
        if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
            run_designer "${V8_IB_CONNECTION}" /LoadConfigFromFiles "${XML_PATH}" -Extension "${V8_EXT_NAME}"
            print_designer_log "${V8_DESIGNER_LOG}"
        else
            if [[ -n "${V8_IB_SERVER:-}" ]]; then
                "${IBCMD_TOOL}" infobase config import --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" "${XML_PATH}"
            else
                "${IBCMD_TOOL}" infobase config import --data="${IBCMD_DATA}" --db-path="${IB_PATH}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" "${XML_PATH}"
            fi
        fi
        ERROR_CODE=$?
        if [[ "${ERROR_CODE}" -eq 0 ]]; then
            run_update_db "${V8_IB_CONNECTION}" "${V8_EXT_NAME}"
            ERROR_CODE=$?
        fi
        cleanup_and_exit
    fi
fi

SRC_EXT="${V8_SRC_PATH: -4}"
if [[ "${SRC_EXT,,}" == ".cfe" ]]; then
    echo "[INFO] Source type: Configuration extension file (CFE)"

    # --- export_cfe ---
    echo "[INFO] Loading configuration extension from file \"${V8_SRC_PATH}\" to infobase \"${IB_PATH}\"..."

    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        run_designer "${V8_IB_CONNECTION}" /LoadCfg "${V8_SRC_PATH}" -Extension "${V8_EXT_NAME}"
        print_designer_log "${V8_DESIGNER_LOG}"
    else
        if [[ -n "${V8_IB_SERVER:-}" ]]; then
            "${IBCMD_TOOL}" infobase config load --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" --force "${V8_SRC_PATH}"
        else
            "${IBCMD_TOOL}" infobase config load --data="${IBCMD_DATA}" --db-path="${IB_PATH}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" --force "${V8_SRC_PATH}"
        fi
    fi
    ERROR_CODE=$?
    if [[ "${ERROR_CODE}" -eq 0 ]]; then
        run_update_db "${V8_IB_CONNECTION}" "${V8_EXT_NAME}"
        ERROR_CODE=$?
    fi
    cleanup_and_exit
fi

echo "[ERROR] Wrong path \"${V8_SRC_PATH}\"!"
echo "Configuration extension binary (*.cfe) or folder containing configuration extension in 1C:Designer XML format or 1C:EDT project expected."
ERROR_CODE=1
cleanup_and_exit
