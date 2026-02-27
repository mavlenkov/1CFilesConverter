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
    echo '[ERROR] Missed parameter 1 - "infobase, path to folder contains 1C extension in 1C:Designer XML format or EDT project"'
    ERROR_CODE=1
fi
if [[ -z "${V8_DST_PATH}" ]]; then
    echo '[ERROR] Missed parameter 2 - "path to 1C configuration extension file (*.cfe)"'
    ERROR_CODE=1
fi
if [[ -z "${V8_EXT_NAME}" ]]; then
    echo '[ERROR] Missed parameter 3 - "configuration extension name"'
    ERROR_CODE=1
fi
if [[ "${ERROR_CODE}" -ne 0 ]]; then
    echo "======"
    echo "[ERROR] Input parameters error. Expected:"
    echo "    %1 - infobase, path to folder contains 1C extension in 1C:Designer XML format or EDT project"
    echo "    %2 - path to 1C configuration extension file (*.cfe)"
    echo "    %3 - configuration extension name"
    echo ""
    cleanup_and_exit
fi

echo "[INFO] Clear temporary files..."
[[ -d "${LOCAL_TEMP}" ]] && rm -rf "${LOCAL_TEMP}"
mkdir -p "${LOCAL_TEMP}"
[[ -n "${V8_DST_FOLDER:-}" ]] && [[ ! -d "${V8_DST_FOLDER}" ]] && mkdir -p "${V8_DST_FOLDER}"

echo "[INFO] Checking 1C extension source type..."

V8_SRC_TYPE=""

if [[ -d "${V8_SRC_PATH}/DT-INF" ]] && [[ -f "${V8_SRC_PATH}/src/Configuration/Configuration.mdo" ]]; then
    if grep -qi "<objectBelonging>" "${V8_SRC_PATH}/src/Configuration/Configuration.mdo" 2>/dev/null; then
        echo "[INFO] Source type: 1C:EDT project"
        mkdir -p "${XML_PATH}"
        mkdir -p "${WS_PATH}"
        V8_SRC_TYPE="edt"
    fi
fi
if [[ -z "${V8_SRC_TYPE}" ]] && [[ -f "${V8_SRC_PATH}/Configuration.xml" ]]; then
    if grep -qi "<objectBelonging>" "${V8_SRC_PATH}/Configuration.xml" 2>/dev/null; then
        echo "[INFO] Source type: 1C:Designer XML files"
        XML_PATH="${V8_SRC_PATH}"
        V8_SRC_TYPE="xml"
    fi
fi

if [[ -z "${V8_SRC_TYPE}" ]]; then
    V8_SRC_TYPE="ib"
    local_prefix="${V8_SRC_PATH:0:2}"
    local_prefix_lc="${local_prefix,,}"

    if [[ "${local_prefix_lc}" == "/f" ]]; then
        IB_PATH="${V8_SRC_PATH:2}"
        echo "[INFO] Basic config type: File infobase (${IB_PATH})"
        V8_BASE_IB_CONNECTION="File=\"${IB_PATH}\";"
    elif [[ "${local_prefix_lc}" == "/s" ]]; then
        IB_PATH="${V8_SRC_PATH:2}"
        IFS='\\/' read -r V8_BASE_IB_SERVER V8_BASE_IB_NAME <<< "${IB_PATH}"
        IB_PATH="${V8_BASE_IB_SERVER}\\${V8_BASE_IB_NAME}"
        echo "[INFO] Basic config type: Server infobase (${V8_BASE_IB_SERVER}\\${V8_BASE_IB_NAME})"
        V8_BASE_IB_CONNECTION="Srvr=\"${V8_BASE_IB_SERVER}\";Ref=\"${V8_BASE_IB_NAME}\";"
        : "${V8_DB_SRV_DBMS:=MSSQLServer}"
    elif is_file_ib "${V8_SRC_PATH}"; then
        IB_PATH="${V8_SRC_PATH}"
        echo "[INFO] Basic config type: File infobase (${V8_SRC_PATH})"
        V8_BASE_IB_CONNECTION="File=\"${IB_PATH}\";"
    else
        echo "[ERROR] Wrong path \"${V8_SRC_PATH}\"!"
        echo "Infobase or folder containing configuration extension in 1C:Designer XML format or 1C:EDT project expected."
        ERROR_CODE=1
        cleanup_and_exit
    fi
fi

# --- base_ib (for edt and xml types) ---
if [[ "${V8_SRC_TYPE}" == "edt" ]] || [[ "${V8_SRC_TYPE}" == "xml" ]]; then
    echo "[INFO] Set basic infobase for export configuration extension..."

    parse_base_ib "${V8_BASE_IB:-}"

    # --- prepare_ib ---
    if [[ -n "${V8_BASE_IB:-}" ]]; then
        V8_BASE_IB="${V8_BASE_IB//\"/}"
    else
        echo '[INFO] Environment variable "V8_BASE_IB" is not defined, temporary file infobase will be used.'
        V8_BASE_IB=""
    fi
    if [[ -n "${V8_BASE_CONFIG:-}" ]]; then
        V8_BASE_CONFIG="${V8_BASE_CONFIG//\"/}"
    else
        echo '[INFO] Environment variable "V8_BASE_CONFIG" is not defined, empty configuration will be used.'
        V8_BASE_CONFIG=""
    fi

    if [[ -n "${V8_BASE_CONFIG}" ]]; then
        [[ ! -d "${IB_PATH}" ]] && mkdir -p "${IB_PATH}"
        "${SCRIPT_DIR}/conf2ib.sh" "${V8_BASE_CONFIG}" "${IB_PATH}"
        if [[ $? -ne 0 ]]; then
            echo "[ERROR] Error cheking type of basic configuration \"${V8_BASE_CONFIG}\"!"
            echo "File or server infobase, configuration file (*.cf), 1C:Designer XML, 1C:EDT project or no configuration expected."
            ERROR_CODE=1
            cleanup_and_exit
        fi
    fi

    # --- export ---
    if [[ "${V8_SRC_TYPE}" == "edt" ]]; then
        # --- export_edt ---
        echo "[INFO] Export configuration extension from 1C:EDT format \"${V8_SRC_PATH}\" to 1C:Designer XML format \"${XML_PATH}\"..."

        run_edt_export "${V8_SRC_PATH}" "${XML_PATH}"
        if [[ $? -ne 0 ]]; then
            ERROR_CODE=$?
            cleanup_and_exit
        fi
    fi

    # --- load_xml ---
    echo "[INFO] Loading configuration extension from XML-files \"${XML_PATH}\" to infobase \"${IB_PATH}\"..."
    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        run_designer "${V8_BASE_IB_CONNECTION}" /LoadConfigFromFiles "${XML_PATH}" -Extension "${V8_EXT_NAME}"
        print_designer_log "${V8_DESIGNER_LOG}"
    else
        if [[ -n "${V8_BASE_IB_SERVER:-}" ]]; then
            "${IBCMD_TOOL}" infobase config import --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_BASE_IB_SERVER}" --db-name="${V8_BASE_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" "${XML_PATH}"
        else
            "${IBCMD_TOOL}" infobase config import --data="${IBCMD_DATA}" --db-path="${IB_PATH}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" "${XML_PATH}"
        fi
    fi
    if [[ $? -ne 0 ]]; then
        ERROR_CODE=$?
        cleanup_and_exit
    fi
fi

# --- export_ib ---
echo "[INFO] Export configuration extension from infobase \"${IB_PATH}\" configuration to \"${V8_DST_PATH}\"..."
if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
    run_designer "${V8_BASE_IB_CONNECTION}" /DumpCfg "${V8_DST_PATH}" -Extension "${V8_EXT_NAME}"
    print_designer_log "${V8_DESIGNER_LOG}"
else
    if [[ -n "${V8_BASE_IB_SERVER:-}" ]]; then
        "${IBCMD_TOOL}" infobase config save --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_BASE_IB_SERVER}" --db-name="${V8_BASE_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" "${V8_DST_PATH}"
    else
        "${IBCMD_TOOL}" infobase config save --data="${IBCMD_DATA}" --db-path="${IB_PATH}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --extension="${V8_EXT_NAME}" "${V8_DST_PATH}"
    fi
fi
ERROR_CODE=$?

cleanup_and_exit
