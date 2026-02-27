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

init_common "Convert 1C configuration to 1C configuration file (*.cf)"
init_convert_tool 1 || cleanup_and_exit
init_temp_paths

# Parse arguments
V8_SRC_PATH="${V8_SRC_PATH:-${1:-}}"
V8_DST_PATH="${V8_DST_PATH:-${2:-}}"
if [[ -n "${V8_DST_PATH}" ]]; then
    V8_DST_FOLDER="$(dirname "${V8_DST_PATH}")"
fi

# Validate
if [[ -z "${V8_SRC_PATH}" ]]; then
    echo '[ERROR] Missed parameter 1 - "path to 1C configuration source (infobase, 1C:Designer XML files or 1C:EDT project)"'
    ERROR_CODE=1
fi
if [[ -z "${V8_DST_PATH}" ]]; then
    echo '[ERROR] Missed parameter 2 - "path to 1C configuration file (*.cf)"'
    ERROR_CODE=1
fi
if [[ "${ERROR_CODE}" -ne 0 ]]; then
    echo "======"
    echo "[ERROR] Input parameters error. Expected:"
    echo "    %1 - path to 1C configuration source (infobase, 1C:Designer XML files or 1C:EDT project)"
    echo "    %2 - path to 1C configuration file (*.cf)"
    echo ""
    cleanup_and_exit
fi

echo "[INFO] Clear temporary files..."
[[ -d "${LOCAL_TEMP}" ]] && rm -rf "${LOCAL_TEMP}"
mkdir -p "${LOCAL_TEMP}"
[[ -n "${V8_DST_FOLDER:-}" ]] && [[ ! -d "${V8_DST_FOLDER}" ]] && mkdir -p "${V8_DST_FOLDER}"

echo "[INFO] Checking configuration source type..."

NEED_XML=0
NEED_IB=0

if [[ -d "${V8_SRC_PATH}/DT-INF" ]]; then
    echo "[INFO] Source type: 1C:EDT project"
    V8_IB_CONNECTION="File=\"${IB_PATH}\";"

    # --- export_edt ---
    [[ ! -d "${XML_PATH}" ]] && mkdir -p "${XML_PATH}"
    mkdir -p "${WS_PATH}"

    echo "[INFO] Export \"${V8_SRC_PATH}\" to 1C:Designer XML format \"${XML_PATH}\"..."
    run_edt_export "${V8_SRC_PATH}" "${XML_PATH}"
    if [[ $? -ne 0 ]]; then
        ERROR_CODE=$?
        cleanup_and_exit
    fi
    NEED_XML=1
elif [[ -f "${V8_SRC_PATH}/Configuration.xml" ]]; then
    echo "[INFO] Source type: 1C:Designer XML files"
    XML_PATH="${V8_SRC_PATH}"
    V8_IB_CONNECTION="File=\"${IB_PATH}\";"
    NEED_XML=1
else
    local_prefix="${V8_SRC_PATH:0:2}"
    local_prefix_lc="${local_prefix,,}"

    if [[ "${local_prefix_lc}" == "/f" ]]; then
        IB_PATH="${V8_SRC_PATH:2}"
        echo "[INFO] Source type: File infobase (${IB_PATH})"
        V8_IB_CONNECTION="File=\"${IB_PATH}\";"
        NEED_IB=1
    elif [[ "${local_prefix_lc}" == "/s" ]]; then
        IB_PATH="${V8_SRC_PATH:2}"
        IFS='\\/' read -r V8_IB_SERVER V8_IB_NAME <<< "${IB_PATH}"
        echo "[INFO] Source type: Server infobase (${V8_IB_SERVER}\\${V8_IB_NAME})"
        IB_PATH="${V8_IB_SERVER}\\${V8_IB_NAME}"
        V8_IB_CONNECTION="Srvr=\"${V8_IB_SERVER}\";Ref=\"${V8_IB_NAME}\";"
        : "${V8_DB_SRV_DBMS:=MSSQLServer}"
        NEED_IB=1
    elif is_file_ib "${V8_SRC_PATH}"; then
        echo "[INFO] Source type: File infobase (${V8_SRC_PATH})"
        IB_PATH="${V8_SRC_PATH}"
        V8_IB_CONNECTION="File=\"${V8_SRC_PATH}\";"
        NEED_IB=1
    else
        echo "[ERROR] Error cheking type of configuration \"${V8_SRC_PATH}\"!"
        echo "Infobase, 1C:Designer XML files or 1C:EDT project expected."
        ERROR_CODE=1
        cleanup_and_exit
    fi
fi

# --- export_xml -> export_ib chain ---
if [[ "${NEED_XML}" == "1" ]]; then
    [[ ! -d "${IB_PATH}" ]] && mkdir -p "${IB_PATH}"

    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        echo "[INFO] Creating infobase \"${IB_PATH}\"..."
        "${V8_TOOL}" CREATEINFOBASE "${V8_IB_CONNECTION}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}"
        print_designer_log "${V8_DESIGNER_LOG}"

        echo "[INFO] Loading infobase \"${IB_PATH}\" configuration from XML-files \"${XML_PATH}\"..."
        "${V8_TOOL}" DESIGNER /IBConnectionString "${V8_IB_CONNECTION}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}" /LoadConfigFromFiles "${XML_PATH}"
        print_designer_log "${V8_DESIGNER_LOG}"
    else
        echo "[INFO] Creating infobase \"${IB_PATH}\" with configuration from XML-files \"${XML_PATH}\"..."
        "${IBCMD_TOOL}" infobase create --data="${IBCMD_DATA}" --db-path="${IB_PATH}" --create-database --import="${XML_PATH}"
    fi
    if [[ $? -ne 0 ]]; then
        ERROR_CODE=$?
        cleanup_and_exit
    fi
    NEED_IB=1
fi

# --- export_ib ---
if [[ "${NEED_IB}" == "1" ]]; then
    echo "[INFO] Export infobase \"${IB_PATH}\" configuration to \"${V8_DST_PATH}\"..."
    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        run_designer "${V8_IB_CONNECTION}" /DumpCfg "${V8_DST_PATH}"
        print_designer_log "${V8_DESIGNER_LOG}"
    else
        if [[ -n "${V8_IB_SERVER:-}" ]]; then
            "${IBCMD_TOOL}" infobase config save --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" "${V8_DST_PATH}"
        else
            "${IBCMD_TOOL}" infobase config save --data="${IBCMD_DATA}" --db-path="${IB_PATH}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" "${V8_DST_PATH}"
        fi
    fi
    ERROR_CODE=$?
fi

cleanup_and_exit
