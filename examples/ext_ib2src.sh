#!/bin/bash

export LC_ALL=C.UTF-8

echo "START: $(date '+%Y-%m-%d %H:%M:%S')"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RELATIVE_SRC_PATH="src"

if [[ -z "${V8_TEMP+x}" ]]; then
    V8_TEMP="${TMPDIR:-/tmp}/$(basename "${BASH_SOURCE[0]}" .sh)"
fi

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
    RELATIVE_SRC_CFE_PATH="${RELATIVE_SRC_PATH}"
    CONVERT_SCRIPT_NAME="ext2edt.sh"
    V8_DROP_CONFIG_DUMP=0
else
    RELATIVE_CF_PATH="cf"
    RELATIVE_CFE_PATH="cfe"
    RELATIVE_SRC_CFE_PATH="${RELATIVE_SRC_PATH}/${RELATIVE_CFE_PATH}"
    CONVERT_SCRIPT_NAME="ext2xml.sh"
    if [[ -z "${V8_DROP_CONFIG_DUMP+x}" ]]; then
        V8_DROP_CONFIG_DUMP=1
    fi
fi

if [[ -n "${RELATIVE_CFE_PATH+x}" ]]; then
    EXT_PATH="${SRC_PATH}/${RELATIVE_CFE_PATH}"
    if [[ -d "${EXT_PATH}" ]]; then
        echo "[INFO] Found extensions root folder \"${EXT_PATH}\""
    fi
else
    EXT_PATH="${SRC_PATH}"
fi

FILE_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
EXT_NAME="${FILE_NAME:11}"
if [[ -z "${EXT_NAME}" ]]; then
    echo "[ERROR] Extension name is not defined (rename script to ext_ib2src_<Extension name>.sh)"
    exit 1
fi

if [[ -n "${V8_EXPORT_TOOL+x}" ]]; then
    V8_CONVERT_TOOL="${V8_EXPORT_TOOL}"
fi

V8_CONNECTION_STRING="/S${V8_DB_SRV_ADDR}\\${V8_IB_NAME}"
if [[ "${V8_CONVERT_TOOL,,}" == "designer" ]]; then
    V8_CONNECTION_STRING="/S${V8_SRV_ADDR}\\${V8_IB_NAME}"
fi

echo
echo "======"
echo "Export extension \"${EXT_NAME}\""
echo "======"

TEMP_CONF_PATH="${V8_TEMP}/src"
if [[ -d "${TEMP_CONF_PATH}" ]]; then
    rm -rf "${TEMP_CONF_PATH}"
fi
mkdir -p "${TEMP_CONF_PATH}"

"${REPO_PATH}/tools/1CFilesConverter/scripts/${CONVERT_SCRIPT_NAME}" "${V8_CONNECTION_STRING}" "${TEMP_CONF_PATH}" "${EXT_NAME}"
RESULT=$?

if [[ ${RESULT} -eq 0 ]]; then
    if [[ "${V8_DROP_CONFIG_DUMP}" == "1" ]] && [[ -f "${TEMP_CONF_PATH}/ConfigDumpInfo.xml" ]]; then
        rm -f "${TEMP_CONF_PATH}/ConfigDumpInfo.xml"
    fi

    echo "[INFO] Clear destination folder \"${EXT_PATH}/${EXT_NAME}\""
    if [[ -d "${EXT_PATH}/${EXT_NAME}" ]] && [[ "${V8_EXT_CLEAN_DST}" == "1" ]]; then
        rm -rf "${EXT_PATH}/${EXT_NAME}"
    fi
    mkdir -p "${EXT_PATH}/${EXT_NAME}"

    echo "[INFO] Moving sources from temporary path \"${TEMP_CONF_PATH}\" to \"${EXT_PATH}/${EXT_NAME}\""
    for item in "${TEMP_CONF_PATH}"/*; do
        [[ -e "${item}" ]] && mv -f "${item}" "${EXT_PATH}/${EXT_NAME}/"
    done

    if [[ -d "${REPO_PATH}/.git" ]]; then
        while IFS= read -r line; do
            status="${line:0:1}"
            file_path="${line:3}"
            if [[ "${status}" == "D" ]]; then
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
        done < <(git status --short -- "${EXT_PATH}/${EXT_NAME}")
    fi
fi

if [[ -d "${TEMP_CONF_PATH}" ]]; then
    rm -rf "${TEMP_CONF_PATH}"
fi

echo "FINISH: $(date '+%Y-%m-%d %H:%M:%S')"
