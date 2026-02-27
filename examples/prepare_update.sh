#!/bin/bash

export LC_ALL=C.UTF-8

echo "START: $(date '+%Y-%m-%d %H:%M:%S')"

V8_COMMIT_AUTHOR="1c"
V8_COMMIT_EMAIL="1c@1c.ru"
V8_COMMIT_MESSAGE="Обновлена конфигурация поставщика до версии"

V8_COMMIT_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
echo "V8_COMMIT_DATE: ${V8_COMMIT_DATE}"

V8_VERSION="8.3.23.2040"
V8_EXPORT_TOOL="ibcmd"
V8_SKIP_ENV=1

V8_SUPPORT_INFO="{6,0,0,0,1,0}"

V8_VENDOR_BRANCH="base1c"
V8_UPDATE_BRANCH="develop"

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
    CONVERT_SCRIPT_NAME="conf2edt.sh"
    V8_DROP_CONFIG_DUMP=0
    V8_DROP_SUPPORT=0
else
    RELATIVE_CF_PATH="cf"
    RELATIVE_CFE_PATH="cfe"
    CONVERT_SCRIPT_NAME="conf2xml.sh"
    V8_DROP_CONFIG_DUMP=1
    if [[ -z "${V8_DROP_SUPPORT+x}" ]]; then
        V8_DROP_SUPPORT=1
    fi
fi

V8_VENDOR_CF="$(find "${REPO_PATH}/${V8_VENDOR_BRANCH}" -maxdepth 1 -name "1cv8.cf" -print -quit)"
if [[ -z "${V8_VENDOR_CF}" ]]; then
    echo "[ERROR] Vendor CF file not found in ${REPO_PATH}/${V8_VENDOR_BRANCH}"
    exit 1
fi

CONF_PATH="${SRC_PATH}/${RELATIVE_CF_PATH}"
if [[ ! -d "${CONF_PATH}" ]]; then
    echo "[ERROR] Configuration path \"${CONF_PATH}\" not found"
    exit 1
fi

if [[ "${V8_SRC_TYPE,,}" == "edt" ]]; then
    V8_CONF_ROOT_PATH="${CONF_PATH}/src/Configuration/Configuration.mdo"
else
    V8_CONF_ROOT_PATH="${CONF_PATH}/Configuration.xml"
fi

cd "${REPO_PATH}" || exit 1
git checkout "${V8_VENDOR_BRANCH}"
git pull

if [[ -n "${V8_EXPORT_TOOL+x}" ]]; then
    V8_CONVERT_TOOL="${V8_EXPORT_TOOL}"
fi

"${REPO_PATH}/tools/1CFilesConverter/scripts/${CONVERT_SCRIPT_NAME}" "${V8_VENDOR_CF}" "${CONF_PATH}"

if [[ "${V8_DROP_CONFIG_DUMP}" == "1" ]] && [[ -f "${TEMP_CONF_PATH}/ConfigDumpInfo.xml" ]]; then
    rm -f "${TEMP_CONF_PATH}/ConfigDumpInfo.xml"
fi

if [[ "${V8_DROP_SUPPORT}" == "1" ]] && [[ -f "${CONF_PATH}/Ext/ParentConfigurations.bin" ]]; then
    echo "${V8_SUPPORT_INFO}" > "${CONF_PATH}/Ext/ParentConfigurations.bin"
fi

V8_BASE1C_VERSION=""
if [[ -f "${V8_CONF_ROOT_PATH}" ]]; then
    V8_BASE1C_VERSION="$(grep -ioP '(?<=<Version>)[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(?=</Version>)' "${V8_CONF_ROOT_PATH}" | head -1)"
fi

git add "${CONF_PATH}"

"${SCRIPT_DIR}/commit.sh" "${V8_COMMIT_AUTHOR}" "${V8_COMMIT_EMAIL}" "${V8_COMMIT_DATE}" "${V8_COMMIT_MESSAGE} ${V8_BASE1C_VERSION}"

git checkout "${V8_UPDATE_BRANCH}"

git merge --no-commit "${V8_VENDOR_BRANCH}"

echo "FINISH: $(date '+%Y-%m-%d %H:%M:%S')"
