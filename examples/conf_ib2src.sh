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
    CONVERT_SCRIPT_NAME="conf2edt.sh"
    V8_DROP_CONFIG_DUMP=0
else
    RELATIVE_CF_PATH="cf"
    CONVERT_SCRIPT_NAME="conf2xml.sh"
    if [[ -z "${V8_DROP_CONFIG_DUMP+x}" ]]; then
        V8_DROP_CONFIG_DUMP=1
    fi
fi

CONF_PATH="${SRC_PATH}/${RELATIVE_CF_PATH}"
if [[ -d "${CONF_PATH}" ]]; then
    echo "[INFO] Found main configuration folder \"${CONF_PATH}\""
else
    echo "[ERROR] Main configuration folder \"${CONF_PATH}\" not found"
    exit 1
fi

if [[ -d "${V8_DST_PATH:-}" ]] && [[ "${V8_CONF_CLEAN_DST}" == "1" ]]; then
    rm -rf "${V8_DST_PATH}"
    V8_CONF_CLEAN_DST=0
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
echo "Export main configuration"
echo "======"

TEMP_CONF_PATH="${V8_TEMP}/src"
if [[ -d "${TEMP_CONF_PATH}" ]]; then
    rm -rf "${TEMP_CONF_PATH}"
fi
mkdir -p "${TEMP_CONF_PATH}"

"${REPO_PATH}/tools/1CFilesConverter/scripts/${CONVERT_SCRIPT_NAME}" "${V8_CONNECTION_STRING}" "${TEMP_CONF_PATH}"
RESULT=$?

if [[ ${RESULT} -eq 0 ]]; then
    if [[ "${V8_DROP_CONFIG_DUMP}" == "1" ]] && [[ -f "${TEMP_CONF_PATH}/ConfigDumpInfo.xml" ]]; then
        rm -f "${TEMP_CONF_PATH}/ConfigDumpInfo.xml"
    fi

    echo "[INFO] Clear destination folder: ${CONF_PATH}"
    if [[ -d "${CONF_PATH}" ]] && [[ "${V8_CONF_CLEAN_DST}" == "1" ]]; then
        rm -rf "${CONF_PATH}"
    fi
    mkdir -p "${CONF_PATH}"

    echo "[INFO] Moving sources from temporary path \"${TEMP_CONF_PATH}\" to \"${CONF_PATH}\""
    for item in "${TEMP_CONF_PATH}"/*; do
        [[ -e "${item}" ]] && mv -f "${item}" "${CONF_PATH}/"
    done

    if [[ -d "${REPO_PATH}/.git" ]]; then
        while IFS= read -r line; do
            status="${line:0:1}"
            file_path="${line:3}"
            if [[ "${status}" == "D" ]]; then
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
        done < <(git status --short -- "${CONF_PATH}")
    fi
fi

if [[ -d "${TEMP_CONF_PATH}" ]]; then
    rm -rf "${TEMP_CONF_PATH}"
fi

echo "FINISH: $(date '+%Y-%m-%d %H:%M:%S')"
