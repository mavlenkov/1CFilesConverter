#!/bin/bash

export LC_ALL=C.UTF-8

echo "START: $(date '+%Y-%m-%d %H:%M:%S')"

ARG="${1}"
if [[ -n "${ARG}" ]]; then
    V8_BRANCH="${ARG//\"/}"
fi
if [[ -z "${V8_BRANCH+x}" ]]; then
    V8_BRANCH="local"
fi

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
V8_IB_NAME="${FILE_NAME:7}"
if [[ -z "${V8_IB_NAME}" ]]; then
    echo "[ERROR] Infobase name is not defined (rename script to upd_ib_<Infobase name>.sh)"
    exit 1
fi

if [[ -e "${REPO_PATH}/${V8_IB_NAME}.env" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "${key}" || "${key}" =~ ^# ]] && continue
        if [[ -z "${!key+x}" ]]; then
            export "${key}=${value}"
        fi
    done < "${REPO_PATH}/${V8_IB_NAME}.env"
fi

if [[ "${V8_SRC_TYPE,,}" == "edt" ]]; then
    RELATIVE_CF_PATH="main"
else
    RELATIVE_CF_PATH="cf"
    RELATIVE_CFE_PATH="cfe"
fi

CONF_PATH="$(find "${SRC_PATH}" -maxdepth 1 -name "${RELATIVE_CF_PATH}" -print -quit)"
if [[ -n "${CONF_PATH}" ]]; then
    CONF_PATH="$(cd "${CONF_PATH}" && pwd)"
    echo "[INFO] Found main configuration folder \"${CONF_PATH}\""
fi

if [[ -n "${RELATIVE_CFE_PATH}" ]]; then
    EXT_PATH="$(find "${SRC_PATH}" -maxdepth 1 -name "${RELATIVE_CFE_PATH}" -print -quit)"
    if [[ -n "${EXT_PATH}" ]]; then
        EXT_PATH="$(cd "${EXT_PATH}" && pwd)"
        echo "[INFO] Found extensions root folder \"${EXT_PATH}\""
    fi
else
    EXT_PATH="${SRC_PATH}"
fi

if [[ -n "${V8_IMPORT_TOOL+x}" ]]; then
    V8_CONVERT_TOOL="${V8_IMPORT_TOOL}"
fi
if [[ "${V8_CONVERT_TOOL}" != "designer" ]] && [[ "${V8_CONVERT_TOOL}" != "ibcmd" ]]; then
    V8_CONVERT_TOOL="designer"
fi

V8_CONNECTION_STRING="/S${V8_DB_SRV_ADDR}\\${V8_IB_NAME}"
if [[ "${V8_CONVERT_TOOL,,}" == "designer" ]]; then
    V8_CONNECTION_STRING="/S${V8_SRV_ADDR}/${V8_IB_NAME}"
fi

if [[ -z "${V8_TOOL+x}" ]]; then
    V8_TOOL="/opt/1cv8/x86_64/${V8_VERSION}/bin/1cv8"
fi
if [[ "${V8_CONVERT_TOOL}" == "designer" ]] && [[ ! -e "${V8_TOOL}" ]]; then
    echo "[ERROR] Could not find 1C:Designer with path ${V8_TOOL}"
    echo "FINISH: $(date '+%Y-%m-%d %H:%M:%S')"
    exit 1
fi
if [[ -z "${IBCMD_TOOL+x}" ]]; then
    IBCMD_TOOL="/opt/1cv8/x86_64/${V8_VERSION}/bin/ibcmd"
fi
if [[ "${V8_CONVERT_TOOL}" == "ibcmd" ]] && [[ ! -e "${IBCMD_TOOL}" ]]; then
    echo "[ERROR] Could not find ibcmd tool with path ${IBCMD_TOOL}"
    echo "FINISH: $(date '+%Y-%m-%d %H:%M:%S')"
    exit 1
fi

echo "[INFO] Pulling actual sources from ${V8_BRANCH}"
cd "${REPO_PATH}"
WORKING_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

if [[ "${V8_BRANCH,,}" != "local" ]] && [[ "${V8_BRANCH,,}" != "current" ]]; then
    git checkout "${V8_BRANCH}"
fi
if [[ "${V8_BRANCH,,}" != "local" ]]; then
    git pull
fi

ACTUAL_COMMIT="$(git rev-parse HEAD 2>/dev/null)"
if [[ -n "${ACTUAL_COMMIT}" ]]; then
    echo "[INFO] Actual commit \"${ACTUAL_COMMIT}\""
fi

if [[ "${V8_EXTENSIONS}" == "ib" ]]; then
    V8_EXTENSIONS=""
    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        V8_IB_CONNECTION="Srvr=\"${V8_SRV_ADDR}\";Ref=\"${V8_IB_NAME}\";"
        EXT_LIST_FILE="${SCRIPT_DIR}/v8_ext_list.txt"
        "${V8_TOOL}" DESIGNER /IBConnectionString "${V8_IB_CONNECTION}" /N"${V8_IB_USER}" /P"${V8_IB_PWD}" /DisableStartupDialogs /DisableStartupMessages /Out "${EXT_LIST_FILE}" /DumpDBCfgList -AllExtensions
        while IFS= read -r line; do
            EXT_NAME="${line// /}"
            EXT_NAME="${EXT_NAME//\"/}"
            if [[ "${EXT_NAME}" == "${line}" ]]; then
                echo "[INFO] Found extension in infobase: ${EXT_NAME}"
                if [[ -n "${V8_EXTENSIONS}" ]]; then
                    V8_EXTENSIONS="${V8_EXTENSIONS} ${EXT_NAME}"
                else
                    V8_EXTENSIONS="${EXT_NAME}"
                fi
            fi
        done < "${EXT_LIST_FILE}"
        rm -f "${EXT_LIST_FILE}"
    else
        while IFS=':' read -r param_name param_value; do
            param_name="${param_name// /}"
            param_value="${param_value// /}"
            param_value="${param_value//\"/}"
            if [[ "${param_name}" == "name" ]]; then
                EXT_NAME="${param_value}"
                echo "[INFO] Found extension in infobase: ${EXT_NAME}"
                if [[ -n "${V8_EXTENSIONS}" ]]; then
                    V8_EXTENSIONS="${V8_EXTENSIONS} ${EXT_NAME}"
                else
                    V8_EXTENSIONS="${EXT_NAME}"
                fi
            fi
        done < <("${IBCMD_TOOL}" infobase config extension list --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_DB_SRV_ADDR}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR}" --db-pwd="${V8_DB_SRV_PWD}" --user="${V8_IB_USER}" --password="${V8_IB_PWD}" 2>&1)
    fi
else
    if [[ -n "${V8_EXTENSIONS}" ]]; then
        for ext in ${V8_EXTENSIONS}; do
            echo "[INFO] Found extension in environment settings: ${ext}"
        done
    fi
fi

V8_CONNECTION_STRING="/S${V8_DB_SRV_ADDR}\\${V8_IB_NAME}"
if [[ "${V8_CONVERT_TOOL,,}" == "designer" ]]; then
    V8_CONNECTION_STRING="/S${V8_SRV_ADDR}/${V8_IB_NAME}"
fi

CONF_CHANGED=0
SYNC_COMMIT="commit not found"
if [[ -e "${CONF_PATH}/SYNC_COMMIT" ]]; then
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
        if [[ -n "$(git diff --name-only "${SYNC_COMMIT}" "${ACTUAL_COMMIT}" -- "${CONF_PATH}" 2>/dev/null)" ]]; then
            CONF_CHANGED=1
        fi
    fi
    if [[ -n "$(git status --short -- "${CONF_PATH}" 2>/dev/null)" ]]; then
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

EXT_UPDATE_DB=""
for EXT_NAME in ${V8_EXTENSIONS}; do
    EXT_CHANGED=0
    SYNC_COMMIT="commit not found"
    if [[ -e "${EXT_PATH}/${EXT_NAME}/SYNC_COMMIT" ]]; then
        while IFS= read -r line; do
            IFS=':' read -r ib_name commit_hash <<< "${line}"
            if [[ "${ib_name}" == "${V8_IB_NAME}" ]]; then
                SYNC_COMMIT="${commit_hash// /}"
            fi
        done < "${EXT_PATH}/${EXT_NAME}/SYNC_COMMIT"
        echo "[INFO] Extension \"${EXT_NAME}\" last synchronized commit: \"${SYNC_COMMIT}\""
        if [[ "${SYNC_COMMIT}" == "commit not found" ]]; then
            EXT_CHANGED=1
        elif [[ "${SYNC_COMMIT}" != "${ACTUAL_COMMIT}" ]]; then
            if [[ -n "$(git diff --name-only "${SYNC_COMMIT}" "${ACTUAL_COMMIT}" -- "${EXT_PATH}/${EXT_NAME}" 2>/dev/null)" ]]; then
                EXT_CHANGED=1
            fi
        fi
        if [[ -n "$(git status --short -- "${EXT_PATH}/${EXT_NAME}" 2>/dev/null)" ]]; then
            EXT_CHANGED=1
        fi
    else
        EXT_CHANGED=1
    fi
    if [[ "${EXT_CHANGED}" == "1" ]]; then
        echo
        echo "======"
        echo "Import extension \"${EXT_NAME}\""
        echo "======"
        "${REPO_PATH}/tools/1CFilesConverter/scripts/ext2ib.sh" "${EXT_PATH}/${EXT_NAME}" "${V8_CONNECTION_STRING}" "${EXT_NAME}"
        if [[ $? -eq 0 ]]; then
            echo "${V8_IB_NAME}:${ACTUAL_COMMIT}" > "${EXT_PATH}/${EXT_NAME}/SYNC_COMMIT"
        fi
        if [[ -n "${EXT_UPDATE_DB}" ]]; then
            EXT_UPDATE_DB="${EXT_UPDATE_DB} ${EXT_NAME}"
        else
            EXT_UPDATE_DB="${EXT_NAME}"
        fi
    else
        echo "[INFO] Extension \"${EXT_NAME}\" wasn't changed since last synchronized commit"
    fi
done

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
if [[ "${WORKING_BRANCH}" != "${CURRENT_BRANCH}" ]]; then
    git checkout "${WORKING_BRANCH}"
fi

if [[ "${CONF_CHANGED}" == "1" ]]; then
    echo
    echo "======"
    echo "Updating database main configuration"
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
        "${IBCMD_TOOL}" infobase config apply --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_DB_SRV_ADDR}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR}" --db-pwd="${V8_DB_SRV_PWD}" --user="${V8_IB_USER}" --password="${V8_IB_PWD}" --dynamic=force --session-terminate=force --force
    fi
fi

for EXT_NAME in ${EXT_UPDATE_DB}; do
    echo
    echo "======"
    echo "Updating database extension \"${EXT_NAME}\"..."
    echo "======"
    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        V8_IB_CONNECTION="Srvr=\"${V8_SRV_ADDR}\";Ref=\"${V8_IB_NAME}\";"
        V8_DESIGNER_LOG="${SCRIPT_DIR}/v8_designer_output.log"
        "${V8_TOOL}" DESIGNER /IBConnectionString "${V8_IB_CONNECTION}" /N"${V8_IB_USER}" /P"${V8_IB_PWD}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}" /UpdateDBCfg -Dynamic+ -Extension "${EXT_NAME}"
        while IFS= read -r line; do
            if [[ -n "${line}" ]]; then
                echo "[WARN] ${line}"
            fi
        done < "${V8_DESIGNER_LOG}"
    else
        "${IBCMD_TOOL}" infobase config apply --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_DB_SRV_ADDR}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR}" --db-pwd="${V8_DB_SRV_PWD}" --user="${V8_IB_USER}" --password="${V8_IB_PWD}" --extension="${EXT_NAME}" --dynamic=force --session-terminate=force --force
    fi
done

echo "FINISH: $(date '+%Y-%m-%d %H:%M:%S')"
