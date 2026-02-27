#!/bin/bash

export LC_ALL=C.UTF-8

echo "START: $(date '+%Y-%m-%d %H:%M:%S')"

ARG="${1:-}"
ARG="${ARG//\"/}"
V8_UPDATE_DB=0
if [[ "${ARG,,}" == "apply" ]]; then
    V8_UPDATE_DB=1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RELATIVE_SRC_PATH="src"

REPO_PATH="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC_PATH="${REPO_PATH}/${RELATIVE_SRC_PATH}"

if [[ ! -d "${SRC_PATH}" ]]; then
    echo "[ERROR] Path to source files \"${SRC_PATH}\" not found"
    exit 1
fi

if [[ -f "${REPO_PATH}/.env" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "${key}" || "${key}" =~ ^# ]] && continue
        if [[ -z "${!key+x}" ]]; then
            export "${key}=${value}"
        fi
    done < "${REPO_PATH}/.env"
fi

if [[ "${V8_SRC_TYPE,,}" == "edt" ]]; then
    RELATIVE_CF_PATH="main"
else
    RELATIVE_CF_PATH="cf"
    RELATIVE_CFE_PATH="cfe"
fi

CONF_PATH="${SRC_PATH}/${RELATIVE_CF_PATH}"
if [[ -d "${CONF_PATH}" ]]; then
    echo "[INFO] Found main configuration folder \"${CONF_PATH}\""
else
    echo "[ERROR] Main configuration folder \"${CONF_PATH}\" not found"
    exit 1
fi

ACTUAL_COMMIT="$(git rev-parse HEAD)"
echo "[INFO] Actual commit \"${ACTUAL_COMMIT}\""

if [[ -n "${V8_IMPORT_TOOL+x}" ]]; then
    V8_CONVERT_TOOL="${V8_IMPORT_TOOL}"
fi

V8_CONNECTION_STRING="/S${V8_DB_SRV_ADDR}\\${V8_IB_NAME}"
if [[ "${V8_CONVERT_TOOL,,}" == "designer" ]]; then
    V8_CONNECTION_STRING="/S${V8_SRV_ADDR}\\${V8_IB_NAME}"
fi

CONF_CHANGED=0
SYNC_COMMIT="commit not found"
if [[ -f "${CONF_PATH}/SYNC_COMMIT" ]]; then
    while IFS= read -r line; do
        IFS=':' read -r ib_name commit_hash <<< "${line}"
        if [[ "${ib_name}" == "${V8_IB_NAME}" ]]; then
            SYNC_COMMIT="${commit_hash// /}"
        fi
    done < "${CONF_PATH}/SYNC_COMMIT"

    echo "[INFO] Main configuration last synchronized commit \"${SYNC_COMMIT}\""
    if [[ "${SYNC_COMMIT}" == "commit not found" ]]; then
        CONF_CHANGED=1
    elif [[ "${SYNC_COMMIT}" != "${ACTUAL_COMMIT}" ]]; then
        DIFF_OUTPUT="$(git diff --name-only "${SYNC_COMMIT}" "${ACTUAL_COMMIT}" -- "${CONF_PATH}")"
        if [[ -n "${DIFF_OUTPUT}" ]]; then
            CONF_CHANGED=1
        fi
    fi
    STATUS_OUTPUT="$(git status --short -- "${CONF_PATH}")"
    if [[ -n "${STATUS_OUTPUT}" ]]; then
        CONF_CHANGED=1
    fi
else
    CONF_CHANGED=1
fi

if [[ "${CONF_CHANGED}" == "1" ]]; then
    echo
    echo "======"
    echo "Import main configuration"
    echo "======"
    "${REPO_PATH}/tools/1CFilesConverter/scripts/conf2ib.sh" "${CONF_PATH}" "${V8_CONNECTION_STRING}"
    if [[ $? -eq 0 ]]; then
        echo "${V8_IB_NAME}:${ACTUAL_COMMIT}" > "${CONF_PATH}/SYNC_COMMIT"
    fi
else
    echo "[INFO] Main configuration wasn't changed since last synchronized commit"
fi

if [[ "${CONF_CHANGED}" == "1" ]] && [[ "${V8_UPDATE_DB}" == "1" ]]; then
    echo
    echo "======"
    echo "Updating database main configuration"
    echo "======"
    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        V8_IB_CONNECTION="Srvr=\"${V8_SRV_ADDR}\";Ref=\"${V8_IB_NAME}\";"
        V8_DESIGNER_LOG="${SCRIPT_DIR}/v8_designer_output.log"
        if [[ -z "${V8_TOOL+x}" ]]; then
            V8_TOOL="/opt/1cv8/x86_64/${V8_VERSION}/bin/1cv8"
        fi
        "${V8_TOOL}" DESIGNER /IBConnectionString "${V8_IB_CONNECTION}" /N"${V8_IB_USER}" /P"${V8_IB_PWD}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}" /UpdateDBCfg -Dynamic+
        while IFS= read -r line; do
            if [[ -n "${line}" ]]; then
                echo "[WARN] ${line}"
            fi
        done < "${V8_DESIGNER_LOG}"
    else
        if [[ -z "${IBCMD_TOOL+x}" ]]; then
            IBCMD_TOOL="/opt/1cv8/x86_64/${V8_VERSION}/bin/ibcmd"
        fi
        "${IBCMD_TOOL}" infobase config apply --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_DB_SRV_ADDR}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR}" --db-pwd="${V8_DB_SRV_PWD}" --user="${V8_IB_USER}" --password="${V8_IB_PWD}" --dynamic=force --session-terminate=force --force
    fi
fi

echo "FINISH: $(date '+%Y-%m-%d %H:%M:%S')"
