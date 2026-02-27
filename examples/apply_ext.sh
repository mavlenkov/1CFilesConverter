#!/bin/bash

export LC_ALL=C.UTF-8

echo "START: $(date '+%Y-%m-%d %H:%M:%S')"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELATIVE_REPO_PATH="${SCRIPT_DIR}/../.."
RELATIVE_SRC_PATH="src"

SRC_PATH="$(find "${RELATIVE_REPO_PATH}" -maxdepth 1 -name "${RELATIVE_SRC_PATH}" -print -quit)"
if [[ -z "${SRC_PATH}" ]]; then
    echo "[ERROR] Path to source files \"${RELATIVE_REPO_PATH}/${RELATIVE_SRC_PATH}\" not found"
    exit 1
fi
SRC_PATH="$(cd "${SRC_PATH}" && pwd)"
REPO_PATH="$(dirname "${SRC_PATH}")"

if [[ -e "${REPO_PATH}/.env" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "${key}" || "${key}" =~ ^# ]] && continue
        if [[ -z "${!key+x}" ]]; then
            export "${key}=${value}"
        fi
    done < "${REPO_PATH}/.env"
fi

FILE_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
V8_EXT_NAME="${FILE_NAME:10}"
if [[ -z "${V8_EXT_NAME}" ]]; then
    echo "[ERROR] Extension name is not defined (rename script to apply_ext_<Extension name>.sh)"
    exit 1
fi

if [[ -n "${V8_IMPORT_TOOL+x}" ]]; then
    V8_CONVERT_TOOL="${V8_IMPORT_TOOL}"
fi

V8_CONNECTION_STRING="/S${V8_DB_SRV_ADDR}\\${V8_IB_NAME}"
if [[ "${V8_CONVERT_TOOL,,}" == "designer" ]]; then
    V8_CONNECTION_STRING="/S${V8_SRV_ADDR}/${V8_IB_NAME}"
fi

echo
echo "======"
echo "Updating database extension \"${V8_EXT_NAME}\"..."
echo "======"
if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
    V8_IB_CONNECTION="Srvr=\"${V8_SRV_ADDR}\";Ref=\"${V8_IB_NAME}\";"
    V8_DESIGNER_LOG="${SCRIPT_DIR}/v8_designer_output.log"
    "${V8_TOOL}" DESIGNER /IBConnectionString "${V8_IB_CONNECTION}" /N"${V8_IB_USER}" /P"${V8_IB_PWD}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}" /UpdateDBCfg -Dynamic+
    while IFS= read -r line; do
        if [[ -n "${line}" ]]; then
            echo "[WARN] ${line}"
        fi
    done < "${V8_DESIGNER_LOG}"
else
    "${IBCMD_TOOL}" infobase config apply --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_DB_SRV_ADDR}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR}" --db-pwd="${V8_DB_SRV_PWD}" --user="${V8_IB_USER}" --password="${V8_IB_PWD}" --extension="${V8_EXT_NAME}" --dynamic=force --session-terminate=force --force
fi

echo "FINISH: $(date '+%Y-%m-%d %H:%M:%S')"
