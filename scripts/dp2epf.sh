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

init_common "Convert 1C external data processors & reports to binary format (*.epf, *.erf)"
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
    echo '[ERROR] Missed parameter 1 - "path to folder contains 1C data processors & reports in 1C:Designer XML or 1C:EDT project format or path to main xml-file of data processor or report"'
    ERROR_CODE=1
else
    if [[ ! -e "${V8_SRC_PATH}" ]]; then
        echo "[ERROR] Path \"${V8_SRC_PATH}\" doesn't exist (parameter 1)."
        ERROR_CODE=1
    fi
fi
if [[ -z "${V8_DST_PATH}" ]]; then
    echo '[ERROR] Missed parameter 2 - "path to folder to save data processors & reports in binary format (*.epf, *.erf)"'
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
    echo "    %1 - path to folder contains 1C data processors & reports in 1C:Designer XML format or EDT format"
    echo "          or path to main xml-file of data processor or report"
    echo '    %2 - path to folder to save data processors & reports in binary format (*.epf, *.erf)"'
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

    # --- export_edt ---
    echo "[INFO] Export external data processors & reports from 1C:EDT format \"${V8_SRC_PATH}\" to 1C:Designer XML format \"${XML_PATH}\"..."
    mkdir -p "${XML_PATH}"
    mkdir -p "${WS_PATH}"

    run_edt_export "${V8_SRC_PATH}" "${XML_PATH}"
    if [[ $? -ne 0 ]]; then
        ERROR_CODE=$?
        cleanup_and_exit
    fi

    # --- export_xml (EDT) ---

    echo "[INFO] Import external data processors from \"${XML_PATH}\" to 1C:Designer format \"${V8_DST_PATH}\" using infobase \"${IB_PATH}\"..."
    if [[ -d "${XML_PATH}/ExternalDataProcessors" ]]; then
        for f in "${XML_PATH}/ExternalDataProcessors"/*.xml; do
            [[ ! -f "${f}" ]] && continue
            local_name="$(basename "${f}" .xml)"
            echo "[INFO] Building ${local_name}..."
            run_designer "${V8_BASE_IB_CONNECTION}" /LoadExternalDataProcessorOrReportFromFiles "${f}" "${V8_DST_PATH}"
            print_designer_log "${V8_DESIGNER_LOG}"
        done
    fi
    echo "[INFO] Import external reports from \"${XML_PATH}\" to 1C:Designer format \"${V8_DST_PATH}\" using infobase \"${IB_PATH}\"..."
    if [[ -d "${XML_PATH}/ExternalReports" ]]; then
        for f in "${XML_PATH}/ExternalReports"/*.xml; do
            [[ ! -f "${f}" ]] && continue
            local_name="$(basename "${f}" .xml)"
            echo "[INFO] Building ${local_name}..."
            run_designer "${V8_BASE_IB_CONNECTION}" /LoadExternalDataProcessorOrReportFromFiles "${f}" "${V8_DST_PATH}"
            print_designer_log "${V8_DESIGNER_LOG}"
        done
    fi
    ERROR_CODE=$?
    cleanup_and_exit
fi

SRC_EXT="${V8_SRC_PATH: -4}"

if [[ "${SRC_EXT,,}" == ".xml" ]]; then
    echo "[INFO] Source type: 1C:Designer XML files (external data processor or report)"
    V8_SRC_MASK="${V8_SRC_PATH}"
    XML_PATH="${V8_SRC_FOLDER}"
elif [[ "${SRC_EXT,,}" == ".epf" ]]; then
    echo "[INFO] Source type: External data processor binary file (epf)"
    V8_SRC_MASK="${V8_SRC_PATH}"
elif [[ "${SRC_EXT,,}" == ".erf" ]]; then
    echo "[INFO] Source type: External report binary file (erf)"
    V8_SRC_MASK="${V8_SRC_PATH}"
else
    # Check for binary files
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
            XML_PATH="${V8_SRC_PATH}"
            V8_SRC_MASK="DIR_XML"
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

# --- export_xml ---
mkdir -p "${WS_PATH}"

echo "[INFO] Export dataprocessors & reports from 1C:Designer XML format \"${XML_PATH}\" to 1C:EDT format \"${V8_DST_PATH}\"..."
run_edt_import "${XML_PATH}" "${V8_DST_PATH}"
if [[ $? -ne 0 ]]; then
    ERROR_CODE=$?
    cleanup_and_exit
fi

run_edt_cleanup "${V8_DST_PATH}"
ERROR_CODE=$?

cleanup_and_exit
