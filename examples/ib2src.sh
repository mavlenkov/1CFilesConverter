#!/bin/bash

export LC_ALL=C.UTF-8

echo "START: $(date '+%Y-%m-%d %H:%M:%S')"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELATIVE_REPO_PATH="${SCRIPT_DIR}/../.."
RELATIVE_SRC_PATH="src"

if [[ -z "${V8_TEMP+x}" ]]; then
    V8_TEMP="/tmp/$(basename "${BASH_SOURCE[0]}" .sh)"
fi

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

if [[ "${V8_SRC_TYPE,,}" == "edt" ]]; then
    RELATIVE_CF_PATH="main"
    RELATIVE_SRC_CFE_PATH="${RELATIVE_SRC_PATH}"
    CONVERT_CONF_SCRIPT_NAME="conf2edt.sh"
    CONVERT_EXT_SCRIPT_NAME="ext2edt.sh"
    V8_DROP_CONFIG_DUMP="0"
else
    RELATIVE_CF_PATH="cf"
    RELATIVE_CFE_PATH="cfe"
    RELATIVE_SRC_CFE_PATH="${RELATIVE_SRC_PATH}/${RELATIVE_CFE_PATH}"
    CONVERT_CONF_SCRIPT_NAME="conf2xml.sh"
    CONVERT_EXT_SCRIPT_NAME="ext2xml.sh"
    if [[ -z "${V8_DROP_CONFIG_DUMP+x}" ]]; then
        V8_DROP_CONFIG_DUMP="1"
    fi
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

if [[ -n "${V8_EXPORT_TOOL+x}" ]]; then
    V8_CONVERT_TOOL="${V8_EXPORT_TOOL}"
fi

V8_CONNECTION_STRING="/S${V8_DB_SRV_ADDR}\\${V8_IB_NAME}"
if [[ "${V8_CONVERT_TOOL,,}" == "designer" ]]; then
    V8_CONNECTION_STRING="/S${V8_SRV_ADDR}/${V8_IB_NAME}"
fi

echo
echo "======"
echo "Export main configuration"
echo "======"

TEMP_CONF_PATH="${V8_TEMP}/src"
if [[ -e "${TEMP_CONF_PATH}" ]]; then
    rm -rf "${TEMP_CONF_PATH}"
fi
mkdir -p "${TEMP_CONF_PATH}"

"${REPO_PATH}/tools/1CFilesConverter/scripts/${CONVERT_CONF_SCRIPT_NAME}" "${V8_CONNECTION_STRING}" "${TEMP_CONF_PATH}"

if [[ $? -eq 0 ]]; then
    if [[ "${V8_DROP_CONFIG_DUMP}" == "1" ]] && [[ -e "${TEMP_CONF_PATH}/ConfigDumpInfo.xml" ]]; then
        rm -f "${TEMP_CONF_PATH}/ConfigDumpInfo.xml"
    fi

    echo "[INFO] Clear destination folder: ${CONF_PATH}"
    if [[ -e "${CONF_PATH}" ]] && [[ "${V8_CONF_CLEAN_DST}" == "1" ]]; then
        rm -rf "${CONF_PATH}"
    fi
    mkdir -p "${CONF_PATH}"

    echo "[INFO] Moving sources from temporary path \"${TEMP_CONF_PATH}\" to \"${CONF_PATH}\""
    for item in "${TEMP_CONF_PATH}"/*; do
        [[ ! -e "${item}" ]] && continue
        mv -f "${item}" "${CONF_PATH}/" > /dev/null
    done

    if [[ -e "${REPO_PATH}/.git" ]]; then
        while IFS= read -r status_line; do
            status_flag="${status_line:0:2}"
            status_flag="${status_flag// /}"
            file_path="${status_line:3}"
            if [[ "${status_flag}" == "D" ]]; then
                RESTORE_FILE=0
                for keep_file in ${V8_FILES_TO_KEEP}; do
                    if [[ "${file_path}" == "${RELATIVE_SRC_PATH}/${RELATIVE_CF_PATH}/${keep_file}" ]]; then
                        RESTORE_FILE=1
                    fi
                done
                if [[ "${RESTORE_FILE}" == "1" ]]; then
                    echo "[INFO] Restoring special file \"${file_path}\""
                    git checkout HEAD "${file_path}" > /dev/null 2>&1
                fi
            fi
        done < <(git status --short -- "${CONF_PATH}" 2>&1)
    fi
fi

if [[ "${V8_EXTENSIONS}" == "ib" ]]; then
    V8_EXTENSIONS=""
    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
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

for EXT_NAME in ${V8_EXTENSIONS}; do
    echo
    echo "======"
    echo "Export extension \"${EXT_NAME}\""
    echo "======"

    if [[ -e "${TEMP_CONF_PATH}" ]]; then
        rm -rf "${TEMP_CONF_PATH}"
    fi
    mkdir -p "${TEMP_CONF_PATH}"

    "${REPO_PATH}/tools/1CFilesConverter/scripts/${CONVERT_EXT_SCRIPT_NAME}" "${V8_CONNECTION_STRING}" "${TEMP_CONF_PATH}" "${EXT_NAME}"

    if [[ $? -eq 0 ]]; then
        if [[ "${V8_DROP_CONFIG_DUMP}" == "1" ]] && [[ -e "${TEMP_CONF_PATH}/ConfigDumpInfo.xml" ]]; then
            rm -f "${TEMP_CONF_PATH}/ConfigDumpInfo.xml"
        fi

        echo "[INFO] Clear destination folder \"${EXT_PATH}/${EXT_NAME}\""
        if [[ -e "${EXT_PATH}/${EXT_NAME}" ]] && [[ "${V8_EXT_CLEAN_DST}" == "1" ]]; then
            rm -rf "${EXT_PATH}/${EXT_NAME}"
        fi
        mkdir -p "${EXT_PATH}/${EXT_NAME}"

        echo "[INFO] Moving sources from temporary path \"${TEMP_CONF_PATH}\" to \"${EXT_PATH}/${EXT_NAME}\""
        for item in "${TEMP_CONF_PATH}"/*; do
            [[ ! -e "${item}" ]] && continue
            mv -f "${item}" "${EXT_PATH}/${EXT_NAME}/" > /dev/null
        done

        if [[ -e "${REPO_PATH}/.git" ]]; then
            while IFS= read -r status_line; do
                status_flag="${status_line:0:2}"
                status_flag="${status_flag// /}"
                file_path="${status_line:3}"
                if [[ "${status_flag}" == "D" ]]; then
                    RESTORE_FILE=0
                    for keep_file in ${V8_FILES_TO_KEEP}; do
                        if [[ "${file_path}" == "${RELATIVE_SRC_CFE_PATH}/${EXT_NAME}/${keep_file}" ]]; then
                            RESTORE_FILE=1
                        fi
                    done
                    if [[ "${RESTORE_FILE}" == "1" ]]; then
                        echo "[INFO] Restoring special file \"${file_path}\""
                        git checkout HEAD "${file_path}" > /dev/null 2>&1
                    fi
                fi
            done < <(git status --short -- "${EXT_PATH}/${EXT_NAME}" 2>&1)
        fi
    fi
done

if [[ -e "${TEMP_CONF_PATH}" ]]; then
    rm -rf "${TEMP_CONF_PATH}"
fi

echo "FINISH: $(date '+%Y-%m-%d %H:%M:%S')"
