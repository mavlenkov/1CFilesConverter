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

init_common "Load 1C configuration to 1C infobase"
init_convert_tool 1 || cleanup_and_exit
init_temp_paths
XML_PATH="${LOCAL_TEMP}/tmp_xml"

# Parse arguments
V8_SRC_PATH="${V8_SRC_PATH:-${1:-}}"
V8_DST_PATH="${V8_DST_PATH:-${2:-}}"
ARG="${3:-}"
if [[ "${ARG,,}" == "create" ]]; then
    V8_IB_CREATE=1
else
    V8_IB_CREATE="${V8_IB_CREATE:-0}"
fi

# Validate
if [[ -z "${V8_SRC_PATH}" ]]; then
    echo '[ERROR] Missed parameter 1 - "path to 1C configuration source (1C configuration file (*.cf), 1C:Designer XML files or 1C:EDT project)"'
    ERROR_CODE=1
fi
if [[ -z "${V8_DST_PATH}" ]]; then
    echo '[ERROR] Missed parameter 2 - "path to 1C infobase"'
    ERROR_CODE=1
fi
if [[ "${ERROR_CODE}" -ne 0 ]]; then
    echo "======"
    echo "[ERROR] Input parameters error. Expected:"
    echo "    %1 - path to 1C configuration source (1C configuration file (*.cf), 1C:Designer XML files or 1C:EDT project)"
    echo "    %2 - path to 1C infobase"
    echo ""
    cleanup_and_exit
fi

echo "[INFO] Clear temporary files..."
[[ -d "${LOCAL_TEMP}" ]] && rm -rf "${LOCAL_TEMP}"
mkdir -p "${LOCAL_TEMP}"

echo "[INFO] Checking configuration ${V8_DST_PATH} destination type..."

parse_dst_ib_path "${V8_DST_PATH}" || cleanup_and_exit

# --- check_src ---
echo "[INFO] Checking configuration source type..."

SRC_EXT="${V8_SRC_PATH: -3}"
if [[ "${SRC_EXT,,}" == ".cf" ]]; then
    echo "[INFO] Source type: Configuration file (CF)"
    # --- export_cf ---
    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        if [[ "${V8_IB_CREATE}" == "1" ]]; then
            echo "[INFO] Creating infobase \"${IB_PATH}\" from file \"${V8_SRC_PATH}\"..."
            "${V8_TOOL}" CREATEINFOBASE "${V8_IB_CONNECTION}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}" /UseTemplate "${V8_SRC_PATH}"
        else
            echo "[INFO] Loading infobase \"${IB_PATH}\" configuration from file \"${V8_SRC_PATH}\"..."
            run_designer "${V8_IB_CONNECTION}" /LoadCfg "${V8_SRC_PATH}"
        fi
        print_designer_log "${V8_DESIGNER_LOG}"
    else
        if [[ -n "${V8_IB_SERVER:-}" ]]; then
            if [[ "${V8_IB_CREATE}" == "1" ]]; then
                echo "[INFO] Creating infobase \"${IB_PATH}\" from file \"${V8_SRC_PATH}\"..."
                "${IBCMD_TOOL}" infobase create --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --create-database --load="${V8_SRC_PATH}"
            else
                echo "[INFO] Loading infobase \"${IB_PATH}\" configuration from file \"${V8_SRC_PATH}\"..."
                "${IBCMD_TOOL}" infobase config load --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" "${V8_SRC_PATH}"
            fi
        else
            if [[ "${V8_IB_CREATE}" == "1" ]]; then
                echo "[INFO] Creating infobase \"${IB_PATH}\" from file \"${V8_SRC_PATH}\"..."
                "${IBCMD_TOOL}" infobase create --data="${IBCMD_DATA}" --db-path="${V8_DST_PATH}" --create-database --load="${V8_SRC_PATH}"
            else
                echo "[INFO] Loading infobase \"${IB_PATH}\" configuration from file \"${V8_SRC_PATH}\"..."
                "${IBCMD_TOOL}" infobase config load --data="${IBCMD_DATA}" --db-path="${V8_DST_PATH}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" --force "${V8_SRC_PATH}"
            fi
        fi
    fi
    ERROR_CODE=$?
    if [[ "${ERROR_CODE}" -eq 0 ]]; then
        run_update_db "${V8_IB_CONNECTION}"
        ERROR_CODE=$?
    fi
    cleanup_and_exit
fi

NEED_XML=0
NEED_IB=0

if [[ -d "${V8_SRC_PATH}/DT-INF" ]]; then
    echo "[INFO] Source type: 1C:EDT project"
    # --- export_edt ---
    mkdir -p "${XML_PATH}"
    mkdir -p "${WS_PATH}"

    run_edt_export "${V8_SRC_PATH}" "${XML_PATH}"
    ERROR_CODE=$?
    if [[ ${ERROR_CODE} -ne 0 ]]; then
        cleanup_and_exit
    fi
    NEED_XML=1
elif [[ -f "${V8_SRC_PATH}/Configuration.xml" ]]; then
    echo "[INFO] Source type: 1C:Designer XML files"
    XML_PATH="${V8_SRC_PATH}"
    NEED_XML=1
else
    echo "[ERROR] Error cheking type of configuration \"${V8_SRC_PATH}\"!"
    echo "Configuration file (*.cf), 1C:Designer XML files or 1C:EDT project expected."
    ERROR_CODE=1
    cleanup_and_exit
fi

# --- export_xml ---
if [[ "${NEED_XML}" == "1" ]]; then
    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        if [[ "${V8_IB_CREATE}" == "1" ]]; then
            echo "[INFO] Creating infobase \"${IB_PATH}\"..."
            "${V8_TOOL}" CREATEINFOBASE "${V8_IB_CONNECTION}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}"
            print_designer_log "${V8_DESIGNER_LOG}"
        fi
        echo "[INFO] Loading infobase \"${IB_PATH}\" configuration from XML-files \"${XML_PATH}\"..."
        run_designer "${V8_IB_CONNECTION}" /LoadConfigFromFiles "${XML_PATH}"
        print_designer_log "${V8_DESIGNER_LOG}"
    else
        if [[ -n "${V8_IB_SERVER:-}" ]]; then
            if [[ "${V8_IB_CREATE}" == "1" ]]; then
                echo "[INFO] Creating infobase \"${IB_PATH}\" from XML-files \"${XML_PATH}\"..."
                "${IBCMD_TOOL}" infobase create --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --create-database --import="${XML_PATH}"
            else
                echo "[INFO] Loading infobase \"${IB_PATH}\" configuration from XML-files \"${XML_PATH}\"..."
                "${IBCMD_TOOL}" infobase config import --data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" "${XML_PATH}"
            fi
        else
            if [[ "${V8_IB_CREATE}" == "1" ]]; then
                echo "[INFO] Creating infobase \"${IB_PATH}\" from XML-files \"${XML_PATH}\"..."
                "${IBCMD_TOOL}" infobase create --data="${IBCMD_DATA}" --db-path="${V8_DST_PATH}" --create-database --import="${XML_PATH}"
            else
                echo "[INFO] Loading infobase \"${IB_PATH}\" configuration from XML-files \"${XML_PATH}\"..."
                "${IBCMD_TOOL}" infobase config import --data="${IBCMD_DATA}" --db-path="${V8_DST_PATH}" --user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}" "${XML_PATH}"
            fi
        fi
    fi
    ERROR_CODE=$?
fi

if [[ "${ERROR_CODE}" -eq 0 ]]; then
    run_update_db "${V8_IB_CONNECTION}"
    ERROR_CODE=$?
fi

cleanup_and_exit
