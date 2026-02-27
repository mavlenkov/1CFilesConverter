#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONVERT_VERSION="UNKNOWN"
if [[ -f "${SCRIPT_DIR}/../VERSION" ]]; then
    CONVERT_VERSION="$(cat "${SCRIPT_DIR}/../VERSION")"
fi
echo "1C files converter v.${CONVERT_VERSION}"
echo "==="
echo "Creating trigger watching 1C files"

ERROR_CODE=0

if [[ -z "${WATCH_TOOL}" ]]; then
    WATCH_TOOL="$(which watchman 2>/dev/null)"
fi
if [[ -z "${WATCH_TOOL}" ]]; then
    echo "[ERROR] Can't find \"watchman\" tool. Add path to \"watchman\" to \"PATH\" environment variable, or set \"WATCH_TOOL\" variable with full specified path"
    ERROR_CODE=1
fi

ARG="$1"
if [[ -n "${ARG}" ]]; then
    TRIGGER_NAME="${ARG}"
fi
if [[ -z "${TRIGGER_NAME}" ]]; then
    echo "[ERROR] Missed parameter 1 - \"watchman trigger name\""
    ERROR_CODE=1
fi

ARG="$2"
if [[ -n "${ARG}" ]]; then
    WATCH_PATH="${ARG}"
fi
if [[ -z "${WATCH_PATH}" ]]; then
    echo "[ERROR] Missed parameter 2 - \"path to watched root\""
    ERROR_CODE=1
elif [[ ! -e "${WATCH_PATH}" ]]; then
    echo "[ERROR] Path \"${WATCH_PATH}\" doesn't exist (parameter 2)."
    ERROR_CODE=1
fi

ARG="$3"
if [[ -n "${ARG}" ]]; then
    WATCH_FILES="${ARG}"
fi
if [[ -z "${WATCH_FILES}" ]]; then
    echo "[ERROR] Missed parameter 3 - \"files extension to watch for\""
    ERROR_CODE=1
fi
case "${WATCH_FILES}" in
    1cdpr) WATCH_FILES="epf erf" ;;
    1cxml) WATCH_FILES="xml bsl bin mxl png grs geo txt" ;;
    1cedt) WATCH_FILES="mdo bsl bin mxl png grs geo txt" ;;
esac

ARG="$4"
if [[ -n "${ARG}" ]]; then
    WATCH_SCRIPT="${ARG}"
fi
if [[ -z "${WATCH_SCRIPT}" ]]; then
    echo "[ERROR] Missed parameter 4 - \"path to triggered script file (could be 1C converter script name or full path to script file)\""
    ERROR_CODE=1
fi
if [[ -n "${WATCH_SCRIPT}" && ! -f "${WATCH_SCRIPT}" ]]; then
    WATCH_SCRIPT_PATH="$(cd "${SCRIPT_DIR}/../scripts" 2>/dev/null && pwd)"
    if [[ -n "${WATCH_SCRIPT_PATH}" ]]; then
        echo "[WARN] Script file \"${WATCH_SCRIPT}\" doesn't exist (parameter 4). Trying to find in \"${WATCH_SCRIPT_PATH}\" directory."
        WATCH_SCRIPT="${WATCH_SCRIPT_PATH}/${WATCH_SCRIPT}.sh"
    fi
fi
if [[ -n "${WATCH_SCRIPT}" && ! -f "${WATCH_SCRIPT}" ]]; then
    echo "[ERROR] Script file \"${WATCH_SCRIPT}\" doesn't exist (parameter 4)."
    ERROR_CODE=1
fi

ARG="$5"
if [[ -n "${ARG}" ]]; then
    WATCH_OUT_PATH="${ARG}"
fi
if [[ -z "${WATCH_OUT_PATH}" ]]; then
    echo "[ERROR] Missed parameter 5 - \"output path to save script results\""
    ERROR_CODE=1
fi
if [[ -n "${WATCH_OUT_PATH}" && ! -d "${WATCH_OUT_PATH}" ]]; then
    mkdir -p "${WATCH_OUT_PATH}"
fi

if [[ ${ERROR_CODE} -ne 0 ]]; then
    echo "==="
    echo "[ERROR] Input parameters error. Expected:"
    echo "    \$1 - watchman trigger name"
    echo "    \$2 - path to watched root"
    echo "    \$3 - files masks to watch for, devided by spaces or one of extension set name:"
    echo "          1cdpr - 1C dataprocessors & reports binaries"
    echo "          1cxml - 1C configuration, extension, dataprocessors or reports in 1C:Designer XML format"
    echo "          1cedt - 1C configuration, extension, dataprocessors or reports in 1C:EDT project"
    echo "    \$4 - path to triggered script file (could be 1C converter script name or full path to script file)"
    echo "    \$5 - output path to save script results"
    echo
    exit ${ERROR_CODE}
fi

# Set watch on the path
WATCH_JSON="[\"watch\", \"${WATCH_PATH}\"]"
echo "${WATCH_JSON}" | "${WATCH_TOOL}" -j

# Build trigger expression
TRIGGER_EXPRESSION="[\"anyof\""
for ext in ${WATCH_FILES}; do
    TRIGGER_EXPRESSION="${TRIGGER_EXPRESSION},[\"imatch\",\"*.${ext}\"]"
done
TRIGGER_EXPRESSION="${TRIGGER_EXPRESSION}]"

# Build trigger command
TRIGGER_SCRIPT="${SCRIPT_DIR}/convert.sh"
TRIGGER_COMMAND="[\"${TRIGGER_SCRIPT}\", \"${WATCH_SCRIPT}\", \"${WATCH_PATH}\", \"${WATCH_OUT_PATH}\"]"

TRIGGER_STDIN="\"NAME_PER_LINE\""

TRIGGER_STDOUT=""
if [[ -n "${WATCH_LOG}" ]]; then
    TRIGGER_STDOUT=", \"stdout\": \">${WATCH_LOG}\""
fi

# Set trigger
TRIGGER_JSON="[\"trigger\", \"${WATCH_PATH}\", {\"name\": \"${TRIGGER_NAME}\", \"expression\": ${TRIGGER_EXPRESSION}, \"command\": ${TRIGGER_COMMAND}, \"stdin\": ${TRIGGER_STDIN}${TRIGGER_STDOUT}}]"
echo "${TRIGGER_JSON}" | "${WATCH_TOOL}" -j
