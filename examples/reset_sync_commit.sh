#!/bin/bash

export LC_ALL=C.UTF-8

ARG="${1:-}"
if [[ -n "${ARG}" ]]; then
    V8_CONF_TO_RESET="${ARG//\"/}"
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

if [[ "${V8_SRC_TYPE,,}" == "edt" ]]; then
    RELATIVE_CF_PATH="main"
else
    RELATIVE_CF_PATH="cf"
    RELATIVE_CFE_PATH="cfe"
fi

CONF_PATH="$(find "${SRC_PATH}" -maxdepth 1 -name "${RELATIVE_CF_PATH}" -print -quit)"
if [[ -n "${CONF_PATH}" ]]; then
    CONF_PATH="$(cd "${CONF_PATH}" && pwd)"
fi
if [[ "${V8_CONF_TO_RESET,,}" == "main" ]] && [[ -z "${CONF_PATH}" ]]; then
    echo "[ERROR] Path to main configuration source files \"${CONF_PATH}\" not found"
    exit 1
fi

EXT_PATH="$(find "${SRC_PATH}" -maxdepth 1 -name "${RELATIVE_CFE_PATH}" -print -quit)"
if [[ -n "${EXT_PATH}" ]]; then
    EXT_PATH="$(cd "${EXT_PATH}" && pwd)"
fi
if [[ -n "${V8_CONF_TO_RESET+x}" ]] && [[ -z "${EXT_PATH}" ]]; then
    echo "[ERROR] Path to extensions source files \"${EXT_PATH}\" not found"
    exit 1
fi
if [[ -n "${V8_CONF_TO_RESET+x}" ]] && [[ "${V8_CONF_TO_RESET,,}" != "main" ]] && [[ "${V8_CONF_TO_RESET,,}" != "ext" ]] && [[ ! -e "${EXT_PATH}/${V8_CONF_TO_RESET}" ]]; then
    echo "[ERROR] Path to extension \"${V8_CONF_TO_RESET}\" source files \"${EXT_PATH}/${V8_CONF_TO_RESET}\" not found"
    exit 1
fi

if [[ -n "${V8_CONF_TO_RESET+x}" ]]; then
    if [[ "${V8_CONF_TO_RESET,,}" == "main" ]]; then
        find "${CONF_PATH}" -name "SYNC_COMMIT" -type f -delete
    elif [[ "${V8_CONF_TO_RESET,,}" == "ext" ]]; then
        find "${EXT_PATH}" -name "SYNC_COMMIT" -type f -delete
    else
        find "${EXT_PATH}/${V8_CONF_TO_RESET}" -name "SYNC_COMMIT" -type f -delete
    fi
else
    find "${SRC_PATH}" -name "SYNC_COMMIT" -type f -delete
fi
