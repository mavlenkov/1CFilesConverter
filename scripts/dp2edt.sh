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

init_common "Convert 1C external data processors & reports to 1C:EDT project"
init_designer_only_tool || cleanup_and_exit
init_temp_paths

# Parse arguments
V8_SRC_PATH="${V8_SRC_PATH:-${1:-}}"
if [[ -n "${V8_SRC_PATH}" ]]; then
    V8_SRC_FOLDER="$(dirname "${V8_SRC_PATH}")"
fi
V8_DST_PATH="${V8_DST_PATH:-${2:-}}"

# Validate
if [[ -z "${V8_SRC_PATH}" ]]; then
    echo '[ERROR] Missed parameter 1 - "path to folder containing data processors (*.epf) & reports (*.erf) in binary or XML format or path to binary data processor (*.epf) or report (*.erf)"'
    ERROR_CODE=1
else
    if [[ ! -e "${V8_SRC_PATH}" ]]; then
        echo "[ERROR] Path \"${V8_SRC_PATH}\" doesn't exist (parameter 1)."
        ERROR_CODE=1
    fi
fi
if [[ -z "${V8_DST_PATH}" ]]; then
    echo '[ERROR] Missed parameter 2 - "path to folder to save 1C data processors & reports in 1C:EDT format"'
    ERROR_CODE=1
fi
if [[ -n "${V8_BASE_IB:-}" ]]; then
    V8_BASE_IB="${V8_BASE_IB//\"/}"
else
    echo '[INFO] Environment variable "V8_BASE_IB" is not defined, temporary file infobase will be used.'
    V8_BASE_IB=""
fi
if [[ -n "${V8_BASE_CONFIG:-}" ]]; then
    V8_BASE_CONFIG="${V8_BASE_CONFIG//\"/}"
else
    echo '[INFO] Environment variable "V8_BASE_CONFIG" is not defined, empty configuration will be used.'
    V8_BASE_CONFIG=""
fi
if [[ "${ERROR_CODE}" -ne 0 ]]; then
    echo "======"
    echo "[ERROR] Input parameters error. Expected:"
    echo "    %1 - path to folder containing data processors (*.epf) & reports (*.erf) in binary or XML format"
    echo "          or path to binary data processor (*.epf) or report (*.erf)"
    echo "    %2 - path to folder to save 1C data processors & reports in 1C:EDT format"
    echo ""
    cleanup_and_exit
fi

echo "[INFO] Clear temporary files..."
[[ -d "${LOCAL_TEMP}" ]] && rm -rf "${LOCAL_TEMP}"
mkdir -p "${LOCAL_TEMP}"
if [[ -d "${V8_DST_PATH}" ]] && [[ "${V8_DP_CLEAN_DST:-}" == "1" ]]; then
    rm -rf "${V8_DST_PATH}"
fi
[[ ! -d "${V8_DST_PATH}" ]] && mkdir -p "${V8_DST_PATH}"

echo "[INFO] Set infobase for export data processor/report..."

# --- Set up base infobase ---
if [[ -z "${V8_BASE_IB}" ]]; then
    mkdir -p "${IB_PATH}"
    echo "[INFO] Creating temporary file infobase \"${IB_PATH}\"..."
    V8_BASE_IB_CONNECTION="File=\"${IB_PATH}\";"
    "${V8_TOOL}" CREATEINFOBASE "${V8_BASE_IB_CONNECTION}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}"
    print_designer_log "${V8_DESIGNER_LOG}"
else
    parse_base_ib "${V8_BASE_IB}"
fi

# --- prepare_ib ---
if [[ -n "${V8_BASE_CONFIG}" ]]; then
    [[ ! -d "${IB_PATH}" ]] && mkdir -p "${IB_PATH}"
    "${SCRIPT_DIR}/conf2ib.sh" "${V8_BASE_CONFIG}" "${IB_PATH}"
    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Error cheking type of basic configuration \"${V8_BASE_CONFIG}\"!"
        echo "Infobase, configuration file (*.cf), 1C:Designer XML, 1C:EDT project or no configuration expected."
        ERROR_CODE=1
        cleanup_and_exit
    fi
fi

# --- export ---
echo "[INFO] Checking data processord & reports source type..."

V8_SRC_IS_EDT=0
V8_SRC_MASK=""

if [[ -d "${V8_SRC_PATH}/DT-INF" ]]; then
    [[ -d "${V8_SRC_PATH}/src/ExternalDataProcessors" ]] && V8_SRC_IS_EDT=1
    [[ -d "${V8_SRC_PATH}/src/ExternalReports" ]] && V8_SRC_IS_EDT=1
fi

if [[ "${V8_SRC_IS_EDT}" == "1" ]]; then
    echo "[INFO] Source type: 1C:EDT project"

    # --- export_edt (go to xml then to epf) ---
    echo "[INFO] Export dataprocessors & reports from 1C:EDT project \"${V8_SRC_PATH}\" to 1C:Designer XML format \"${V8_DST_PATH}\"..."
    mkdir -p "${WS_PATH}"

    run_edt_export "${V8_SRC_PATH}" "${V8_DST_PATH}"
    if [[ $? -ne 0 ]]; then
        ERROR_CODE=$?
    fi
    cleanup_and_exit
fi

SRC_EXT="${V8_SRC_PATH: -4}"

if [[ "${SRC_EXT,,}" == ".epf" ]]; then
    echo "[INFO] Source type: External data processor binary file (epf)"
    V8_SRC_MASK="${V8_SRC_PATH}"
elif [[ "${SRC_EXT,,}" == ".erf" ]]; then
    echo "[INFO] Source type: External report binary file (erf)"
    V8_SRC_MASK="${V8_SRC_PATH}"
else
    # Check for epf/erf binary files
    local_found_epf=0
    for f in "${V8_SRC_PATH}"/*.epf "${V8_SRC_PATH}"/*.erf; do
        if [[ -f "${f}" ]]; then
            local_found_epf=1
            break
        fi
    done
    if [[ "${local_found_epf}" == "1" ]]; then
        echo "[INFO] Source type: External data processors (epf) & reports (erf) binary files"
        V8_SRC_FOLDER="${V8_SRC_PATH}"
        V8_SRC_MASK="DIR_EPF"
    else
        # Check for xml files
        local_found_xml=0
        for f in "${V8_SRC_PATH}"/*.xml; do
            if [[ -f "${f}" ]]; then
                local_found_xml=1
                break
            fi
        done
        if [[ "${local_found_xml}" == "1" ]]; then
            echo "[INFO] Source type: 1C:Designer XML files folder (external data processors & reports)"
            V8_SRC_MASK="DIR_XML"
            XML_PATH="${V8_SRC_PATH}"
        else
            echo "[ERROR] Wrong path \"${V8_SRC_PATH}\"!"
            echo "Folder containing external data processors & reports in binary or XML format, data processor binary (*.epf) or report binary (*.erf) expected."
            ERROR_CODE=1
            cleanup_and_exit
        fi
    fi
fi

# --- export_epf ---
if [[ "${SRC_EXT,,}" == ".epf" ]] || [[ "${SRC_EXT,,}" == ".erf" ]] || [[ "${V8_SRC_MASK}" == "DIR_EPF" ]]; then
    echo "[INFO] Export data processors & reports from folder \"${V8_SRC_PATH}\" to 1C:Designer XML format \"${XML_PATH}\" using infobase \"${IB_PATH}\"..."
    mkdir -p "${XML_PATH}"


    if [[ "${V8_SRC_MASK}" == "DIR_EPF" ]]; then
        for f in "${V8_SRC_FOLDER}"/*.epf "${V8_SRC_FOLDER}"/*.erf; do
            [[ ! -f "${f}" ]] && continue
            local_name="$(basename "${f}" | sed 's/\.[^.]*$//')"
            local_file="$(basename "${f}")"
            echo "[INFO] Building ${local_name}..."
            run_designer "${V8_BASE_IB_CONNECTION}" /DumpExternalDataProcessorOrReportToFiles "${XML_PATH}" "${V8_SRC_FOLDER}/${local_file}"
            print_designer_log "${V8_DESIGNER_LOG}"
            if [[ $? -ne 0 ]]; then
                ERROR_CODE=$?
                cleanup_and_exit
            fi
        done
    else
        local_name="$(basename "${V8_SRC_MASK}" | sed 's/\.[^.]*$//')"
        local_file="$(basename "${V8_SRC_MASK}")"
        echo "[INFO] Building ${local_name}..."
        run_designer "${V8_BASE_IB_CONNECTION}" /DumpExternalDataProcessorOrReportToFiles "${XML_PATH}" "${V8_SRC_FOLDER}/${local_file}"
        print_designer_log "${V8_DESIGNER_LOG}"
        if [[ $? -ne 0 ]]; then
            ERROR_CODE=$?
            cleanup_and_exit
        fi
    fi
fi

# --- export_xml (EDT import) ---
mkdir -p "${WS_PATH}"


if [[ "${V8_SRC_IS_EDT}" == "1" ]] || [[ "${V8_SRC_MASK}" == "DIR_XML" ]] || [[ "${SRC_EXT,,}" == ".xml" ]]; then
    if [[ "${V8_SRC_MASK}" == "DIR_XML" ]]; then
        echo "[INFO] Import external datap processors & reports from \"${XML_PATH}\" to 1C:Designer format \"${V8_DST_PATH}\" using infobase \"${IB_PATH}\"..."
        for f in "${XML_PATH}"/*.xml; do
            [[ ! -f "${f}" ]] && continue
            local_name="$(basename "${f}" .xml)"
            echo "[INFO] Building ${local_name}..."
            echo "${V8_DST_PATH}"
            run_designer "${V8_BASE_IB_CONNECTION}" /LoadExternalDataProcessorOrReportFromFiles "${XML_PATH}/$(basename "${f}")" "${V8_DST_PATH}"
            print_designer_log "${V8_DESIGNER_LOG}"
        done
    else
        echo "[INFO] Import external datap processors & reports from \"${XML_PATH}\" to 1C:Designer format \"${V8_DST_PATH}\" using infobase \"${IB_PATH}\"..."
        local_name="$(basename "${V8_SRC_MASK}" | sed 's/\.[^.]*$//')"
        local_file="$(basename "${V8_SRC_MASK}")"
        echo "[INFO] Building ${local_name}..."
        echo "${V8_DST_PATH}"
        run_designer "${V8_BASE_IB_CONNECTION}" /LoadExternalDataProcessorOrReportFromFiles "${XML_PATH}/${local_file}" "${V8_DST_PATH}"
        print_designer_log "${V8_DESIGNER_LOG}"
    fi
fi

ERROR_CODE=$?

cleanup_and_exit
