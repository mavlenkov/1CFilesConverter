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

init_common "Convert 1C configuration to 1C:Designer XML format"
init_convert_tool 1 || cleanup_and_exit
init_temp_paths

# Parse arguments
V8_SRC_PATH="${V8_SRC_PATH:-${1:-}}"
V8_DST_PATH="${V8_DST_PATH:-${2:-}}"

# Validate
if [[ -z "${V8_SRC_PATH}" ]]; then
    echo '[ERROR] Missed parameter 1 - "path to 1C configuration source (1C configuration file (*.cf), infobase or 1C:EDT project)"'
    ERROR_CODE=1
fi
if [[ -z "${V8_DST_PATH}" ]]; then
    echo '[ERROR] Missed parameter 2 - "path to folder to save configuration files in 1C:Designer XML format"'
    ERROR_CODE=1
fi
if [[ "${ERROR_CODE}" -ne 0 ]]; then
    echo "======"
    echo "[ERROR] Input parameters error. Expected:"
    echo "    %1 - path to 1C configuration source (1C configuration file (*.cf), infobase or 1C:EDT project)"
    echo "    %2 - path to folder to save configuration files in 1C:Designer XML format"
    echo ""
    cleanup_and_exit
fi

echo "[INFO] Clear temporary files..."
[[ -d "${LOCAL_TEMP}" ]] && rm -rf "${LOCAL_TEMP}"
mkdir -p "${LOCAL_TEMP}"
if [[ -d "${V8_DST_PATH}" ]] && [[ "${V8_CONF_CLEAN_DST:-}" == "1" ]]; then
    rm -rf "${V8_DST_PATH}"
fi
[[ ! -d "${V8_DST_PATH}" ]] && mkdir -p "${V8_DST_PATH}"

echo "[INFO] Checking configuration source type..."

SRC_EXT="${V8_SRC_PATH: -3}"
NEED_IB=0

if [[ "${SRC_EXT,,}" == ".cf" ]]; then
    echo "[INFO] Source type: Configuration file (CF)"
    V8_IB_CONNECTION="File=\"${IB_PATH}\";"

    # --- export_cf ---
    [[ ! -d "${IB_PATH}" ]] && mkdir -p "${IB_PATH}"

    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        "${V8_TOOL}" CREATEINFOBASE "${V8_IB_CONNECTION}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}" /UseTemplate "${V8_SRC_PATH}"
    else
        if [[ -n "${V8_IB_SERVER:-}" ]]; then
            "${IBCMD_TOOL}" infobase create --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS:-MSSQLServer}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --create-database --load="${V8_SRC_PATH}"
        else
            "${IBCMD_TOOL}" infobase create --data="${IBCMD_DATA}" --db-path="${IB_PATH}" --create-database --load="${V8_SRC_PATH}"
        fi
    fi
    ERROR_CODE=$?
    if [[ ${ERROR_CODE} -ne 0 ]]; then
        cleanup_and_exit
    fi
    NEED_IB=1
elif [[ -d "${V8_SRC_PATH}/DT-INF" ]]; then
    echo "[INFO] Source type: 1C:EDT project"
    V8_IB_CONNECTION="File=\"${IB_PATH}\";"

    # --- export_edt ---
    echo "[INFO] Export \"${V8_SRC_PATH}\" to 1C:Designer XML format \"${V8_DST_PATH}\"..."
    mkdir -p "${WS_PATH}"

    run_edt_export "${V8_SRC_PATH}" "${V8_DST_PATH}"
    ERROR_CODE=$?
    cleanup_and_exit
else
    local_prefix="${V8_SRC_PATH:0:2}"
    local_prefix_lc="${local_prefix,,}"

    if [[ "${local_prefix_lc}" == "/f" ]]; then
        V8_IB_PATH="${V8_SRC_PATH:2}"
        echo "[INFO] Source type: File infobase (${V8_IB_PATH})"
        V8_IB_CONNECTION="File=\"${V8_IB_PATH}\";"
        NEED_IB=1
    elif [[ "${local_prefix_lc}" == "/s" ]]; then
        V8_IB_PATH="${V8_SRC_PATH:2}"
        IFS='\\/' read -r V8_IB_SERVER V8_IB_NAME <<< "${V8_IB_PATH}"
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
    elif [[ -f "${V8_SRC_PATH}/Configuration.xml" ]]; then
        echo "[INFO] Source type: 1C:Designer XML files"
        XML_PATH="${V8_SRC_PATH}"
        V8_IB_CONNECTION="File=\"${IB_PATH}\";"
        # fall through to export_xml -> export_ib not needed, jump to export_ib directly
        # Actually in CMD: goto export_edt falls through to export_xml -> export_ib
        # For XML: goto export_xml falls through to export_ib
        # Need to go through export_xml path but skip export_cf
        NEED_IB=0
        # Will be handled below at export_xml -> export_ib section
    else
        echo "[ERROR] Error cheking type of configuration \"${V8_SRC_PATH}\"!"
        echo "Infobase, configuration file (*.cf) or 1C:EDT project expected."
        ERROR_CODE=1
        cleanup_and_exit
    fi
fi

# --- export_ib ---
echo "[INFO] Export configuration from infobase \"${IB_PATH}\" to 1C:Designer XML format \"${V8_DST_PATH}\"..."
if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
    run_designer "${V8_IB_CONNECTION}" /DumpConfigToFiles "${V8_DST_PATH}" -force
    print_designer_log "${V8_DESIGNER_LOG}"
else
    IBCMD_EXPORT_FLAGS="--force"
    if [[ -f "${V8_DST_PATH}/Configuration.xml" ]] && [[ -f "${V8_DST_PATH}/ConfigDumpInfo.xml" ]]; then
        IBCMD_EXPORT_FLAGS="${IBCMD_EXPORT_FLAGS} --sync"
    fi
    if [[ -n "${V8_IB_SERVER:-}" ]]; then
        "${IBCMD_TOOL}" infobase config export --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" ${IBCMD_EXPORT_FLAGS} "${V8_DST_PATH}"
    else
        "${IBCMD_TOOL}" infobase config export --data="${IBCMD_DATA}" --db-path="${IB_PATH}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" ${IBCMD_EXPORT_FLAGS} "${V8_DST_PATH}"
    fi
fi
ERROR_CODE=$?

cleanup_and_exit
