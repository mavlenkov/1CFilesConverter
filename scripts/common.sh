#!/usr/bin/env bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

# Common library for 1CFilesConverter bash scripts.
# Sourced by individual conversion scripts.

ERROR_CODE=0

# ============================================================
# load_env - load .env file from current directory
# Sets variables only if not already defined.
# ============================================================
load_env() {
    if [[ -f "${PWD}/.env" ]] && [[ "${V8_SKIP_ENV}" != "1" ]]; then
        while IFS= read -r line || [[ -n "${line}" ]]; do
            # Skip empty lines and comments
            [[ -z "${line}" ]] && continue
            [[ "${line}" =~ ^# ]] && continue
            # Split on first '='
            local key="${line%%=*}"
            local value="${line#*=}"
            # Skip lines without '='
            [[ "${key}" == "${line}" ]] && continue
            # Remove surrounding quotes from value
            value="${value#\"}"
            value="${value%\"}"
            # Set only if not already defined
            if [[ -z "${!key+x}" ]]; then
                export "${key}=${value}"
            fi
        done < "${PWD}/.env"
    fi
}

# ============================================================
# init_common "description" - master initialization
# ============================================================
init_common() {
    local description="${1:-}"

    SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
    SCRIPT_NAME="$(basename "$0" .sh)"

    CONVERT_VERSION="UNKNOWN"
    if [[ -f "${SCRIPT_DIR}/../VERSION" ]]; then
        CONVERT_VERSION="$(cat "${SCRIPT_DIR}/../VERSION")"
    fi
    echo "1C files converter v.${CONVERT_VERSION}"
    echo "======"
    if [[ -n "${description}" ]]; then
        echo "[INFO] ${description}"
    fi

    ERROR_CODE=0

    load_env

    : "${V8_VERSION:=8.3.23.2040}"
    : "${V8_TEMP:=/tmp/1c}"

    echo "[INFO] Using 1C:Enterprise, version ${V8_VERSION}"
    echo "[INFO] Using temporary folder \"${V8_TEMP}\""
}

# ============================================================
# init_convert_tool [supports_ibcmd]
#   supports_ibcmd=1 - script supports both designer and ibcmd
#   supports_ibcmd=0 or absent - designer only
# Returns 0 on success, 1 on error (sets ERROR_CODE)
# ============================================================
init_convert_tool() {
    local supports_ibcmd="${1:-0}"

    if [[ "${supports_ibcmd}" == "1" ]]; then
        if [[ "${V8_CONVERT_TOOL}" != "designer" ]] && [[ "${V8_CONVERT_TOOL}" != "ibcmd" ]]; then
            V8_CONVERT_TOOL="designer"
        fi
    else
        V8_CONVERT_TOOL="designer"
    fi

    : "${V8_TOOL:=/opt/1cv8/x86_64/${V8_VERSION}/1cv8}"
    if [[ "${V8_CONVERT_TOOL}" == "designer" ]] && [[ ! -f "${V8_TOOL}" ]]; then
        echo "Could not find 1C:Designer with path ${V8_TOOL}"
        ERROR_CODE=1
        return 1
    fi

    : "${IBCMD_TOOL:=/opt/1cv8/x86_64/${V8_VERSION}/ibcmd}"
    if [[ "${V8_CONVERT_TOOL}" == "ibcmd" ]] && [[ ! -f "${IBCMD_TOOL}" ]]; then
        echo "Could not find ibcmd tool with path ${IBCMD_TOOL}"
        ERROR_CODE=1
        return 1
    fi

    echo "[INFO] Start conversion using \"${V8_CONVERT_TOOL}\""
    return 0
}

# ============================================================
# init_designer_only_tool - for scripts using only designer
# Returns 0 on success, 1 on error
# ============================================================
init_designer_only_tool() {
    : "${V8_TOOL:=/opt/1cv8/x86_64/${V8_VERSION}/1cv8}"
    if [[ ! -f "${V8_TOOL}" ]]; then
        echo "Could not find 1C:Designer with path ${V8_TOOL}"
        ERROR_CODE=1
        return 1
    fi

    echo "[INFO] Start conversion using \"designer\""
    return 0
}

# ============================================================
# init_temp_paths - set up LOCAL_TEMP, IB_PATH, XML_PATH, WS_PATH
# ============================================================
init_temp_paths() {
    LOCAL_TEMP="${V8_TEMP}/${SCRIPT_NAME}"
    : "${IBCMD_DATA:=${V8_TEMP}/ibcmd_data}"
    IB_PATH="${LOCAL_TEMP}/tmp_db"
    XML_PATH="${LOCAL_TEMP}/tmp_xml"
    WS_PATH="${LOCAL_TEMP}/edt_ws"
    V8_DESIGNER_LOG="${LOCAL_TEMP}/v8_designer_output.log"
}

# ============================================================
# detect_edt_tools - find ring/1cedtcli
# Returns 0 on success, 1 on error (sets ERROR_CODE)
# ============================================================
detect_edt_tools() {
    if [[ -z "${RING_TOOL:-}" ]]; then
        local ring_path
        ring_path="$(command -v ring 2>/dev/null || true)"
        if [[ -n "${ring_path}" ]]; then
            RING_TOOL="${ring_path}"
        fi
    fi

    if [[ -z "${EDTCLI_TOOL:-}" ]]; then
        if [[ -n "${V8_EDT_VERSION:-}" ]]; then
            if [[ "${V8_EDT_VERSION:0:4}" -ge 2024 ]] 2>/dev/null; then
                local edt_mask="/opt/1C/1CE/components/1c-edt-${V8_EDT_VERSION}*"
                local edt_dir
                for edt_dir in ${edt_mask}; do
                    if [[ -d "${edt_dir}" ]] && [[ "$(basename "${edt_dir}")" =~ 1c-edt-[0-9]+\.[0-9]+\.[0-9] ]]; then
                        if [[ -f "${edt_dir}/1cedtcli" ]]; then
                            EDTCLI_TOOL="${edt_dir}/1cedtcli"
                        fi
                    fi
                done
            fi
        else
            local edt_mask="/opt/1C/1CE/components/1c-edt-*"
            local edt_dir
            for edt_dir in ${edt_mask}; do
                if [[ -d "${edt_dir}" ]] && [[ "$(basename "${edt_dir}")" =~ 1c-edt-[0-9]+\.[0-9]+\.[0-9] ]]; then
                    if [[ -f "${edt_dir}/1cedtcli" ]]; then
                        EDTCLI_TOOL="${edt_dir}/1cedtcli"
                    fi
                fi
            done
        fi
    fi

    if [[ -z "${RING_TOOL:-}" ]] && [[ -z "${EDTCLI_TOOL:-}" ]]; then
        echo '[ERROR] Can'\''t find "ring" or "edtcli" tool. Add path to "ring" to "PATH" environment variable, or set "RING_TOOL" variable with full specified path to "ring", or set "EDTCLI_TOOL" variable with full specified path to "1cedtcli".'
        ERROR_CODE=1
        return 1
    fi
    return 0
}

# ============================================================
# run_edt_export src_path dst_path
# ============================================================
run_edt_export() {
    local src_path="${1}"
    local dst_path="${2}"

    detect_edt_tools || return 1

    if [[ -n "${EDTCLI_TOOL:-}" ]]; then
        echo '[INFO] Start conversion using "edt cli"'
        "${EDTCLI_TOOL}" -data "${WS_PATH}" -command export --project "${src_path}" --configuration-files "${dst_path}"
    else
        echo '[INFO] Start conversion using "ring"'
        "${RING_TOOL}" edt@"${V8_EDT_VERSION}" workspace export --project "${src_path}" --configuration-files "${dst_path}" --workspace-location "${WS_PATH}"
    fi
    return $?
}

# ============================================================
# run_edt_import src_xml_path dst_project_path
# ============================================================
run_edt_import() {
    local src_path="${1}"
    local dst_path="${2}"

    detect_edt_tools || return 1

    if [[ -n "${EDTCLI_TOOL:-}" ]]; then
        echo '[INFO] Start conversion using "edt cli"'
        "${EDTCLI_TOOL}" -data "${WS_PATH}" -command import --project "${dst_path}" --configuration-files "${src_path}" --version "${V8_VERSION}"
    else
        echo '[INFO] Start conversion using "ring"'
        "${RING_TOOL}" edt@"${V8_EDT_VERSION}" workspace import --project "${dst_path}" --configuration-files "${src_path}" --workspace-location "${WS_PATH}" --version "${V8_VERSION}"
    fi
    return $?
}

# ============================================================
# run_edt_cleanup project_path
# ============================================================
run_edt_cleanup() {
    local project_path="${1}"

    if [[ -n "${EDTCLI_TOOL:-}" ]]; then
        "${EDTCLI_TOOL}" -data "${WS_PATH}" -command clean-up-source --project "${project_path}"
    else
        "${RING_TOOL}" edt@"${V8_EDT_VERSION}" workspace clean-up-source --workspace-location "${WS_PATH}" --project "${project_path}"
    fi
    return $?
}

# ============================================================
# run_edt_validate project_path report_file
# ============================================================
run_edt_validate() {
    local project_path="${1}"
    local report_file="${2}"

    detect_edt_tools || return 1

    if [[ -n "${EDTCLI_TOOL:-}" ]]; then
        echo '[INFO] Start validate using "edt cli"'
        "${EDTCLI_TOOL}" -data "${WS_PATH}" -command validate --project-list "${project_path}" --file "${report_file}"
    else
        echo '[INFO] Start convalidate using "ring"'
        "${RING_TOOL}" edt@"${V8_EDT_VERSION}" workspace validate --project-list "${project_path}" --workspace-location "${WS_PATH}" --file "${report_file}"
    fi
    return $?
}

# ============================================================
# is_file_ib path - check if path is a file infobase
# (case-insensitive check for 1Cv8.1CD on Linux)
# ============================================================
is_file_ib() {
    local dir_path="${1}"
    [[ -d "${dir_path}" ]] || return 1
    local f
    for f in "${dir_path}"/1[Cc][Vv]8.1[Cc][Dd]; do
        [[ -f "${f}" ]] && return 0
    done
    return 1
}

# ============================================================
# run_designer - run 1C:Designer with connection string and optional auth
# Usage: run_designer <connection_string> [designer_args...]
# ============================================================
run_designer() {
    local conn="${1}"
    shift
    local auth_args=()
    [[ -n "${V8_IB_USER:-}" ]] && auth_args+=("/N${V8_IB_USER}")
    [[ -n "${V8_IB_PWD:-}" ]] && auth_args+=("/P${V8_IB_PWD}")
    "${V8_TOOL}" DESIGNER /IBConnectionString "${conn}" "${auth_args[@]}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}" "$@"
}

# ============================================================
# print_designer_log - print designer log with [WARN] prefix
# ============================================================
print_designer_log() {
    local log_file="${1:-${V8_DESIGNER_LOG:-}}"
    if [[ -f "${log_file}" ]]; then
        while IFS= read -r line || [[ -n "${line}" ]]; do
            [[ -n "${line}" ]] && echo "[WARN] ${line}"
        done < "${log_file}"
    fi
}

# ============================================================
# run_update_db - update database configuration
# Usage: run_update_db <connection_string> [extension_name]
# Runs only if V8_UPDATE_DB=1
# ============================================================
run_update_db() {
    [[ "${V8_UPDATE_DB:-0}" != "1" ]] && return 0

    local conn="${1}"
    local ext_name="${2:-}"

    echo "[INFO] Updating database configuration..."

    local ext_args=()
    [[ -n "${ext_name}" ]] && ext_args+=("-Extension" "${ext_name}")

    if [[ "${V8_CONVERT_TOOL}" == "designer" ]]; then
        run_designer "${conn}" /UpdateDBCfg "${ext_args[@]}"
        print_designer_log "${V8_DESIGNER_LOG}"
    else
        local ibcmd_args=()
        if [[ -n "${V8_IB_SERVER:-}" ]]; then
            ibcmd_args+=(--data="${IBCMD_DATA}" --dbms="${V8_DB_SRV_DBMS}" --db-server="${V8_IB_SERVER}" --db-name="${V8_IB_NAME}" --db-user="${V8_DB_SRV_USR:-}" --db-pwd="${V8_DB_SRV_PWD:-}")
        else
            ibcmd_args+=(--data="${IBCMD_DATA}" --db-path="${IB_PATH}")
        fi
        ibcmd_args+=(--user="${V8_IB_USER:-}" --password="${V8_IB_PWD:-}")
        [[ -n "${ext_name}" ]] && ibcmd_args+=(--extension="${ext_name}")
        "${IBCMD_TOOL}" infobase config apply "${ibcmd_args[@]}"
    fi

    if [[ $? -ne 0 ]]; then
        echo "[ERROR] Failed to update database configuration!"
        return $?
    fi
    echo "[INFO] Database configuration updated successfully."
    return 0
}

# ============================================================
# check_error - check last exit code
# ============================================================
check_error() {
    local rc=$?
    if [[ ${rc} -ne 0 ]]; then
        ERROR_CODE=${rc}
    fi
    return ${rc}
}

# ============================================================
# cleanup_and_exit - cleanup and exit with ERROR_CODE
# ============================================================
cleanup_and_exit() {
    echo "[INFO] Clear temporary files..."
    if [[ -d "${LOCAL_TEMP:-}" ]]; then
        rm -rf "${LOCAL_TEMP}"
    fi

    exit "${ERROR_CODE}"
}

# ============================================================
# parse_dst_ib_path - parse destination infobase path
# Sets: IB_PATH, V8_IB_CONNECTION, V8_IB_SERVER, V8_IB_NAME
# Returns 0 on success, 1 on error
# ============================================================
parse_dst_ib_path() {
    local dst_path="${1}"

    local prefix="${dst_path:0:2}"
    local prefix_lc="${prefix,,}"

    if [[ "${prefix_lc}" == "/f" ]]; then
        IB_PATH="${dst_path:2}"
        echo "[INFO] Destination type: File infobase (${IB_PATH})"
        V8_IB_CONNECTION="File=\"${IB_PATH}\";"
        return 0
    fi
    if [[ "${prefix_lc}" == "/s" ]]; then
        IB_PATH="${dst_path:2}"
        IFS='\\/' read -r V8_IB_SERVER V8_IB_NAME <<< "${IB_PATH}"
        echo "[INFO] Destination type: Server infobase (${V8_IB_SERVER}\\${V8_IB_NAME})"
        IB_PATH="${V8_IB_SERVER}\\${V8_IB_NAME}"
        V8_IB_CONNECTION="Srvr=\"${V8_IB_SERVER}\";Ref=\"${V8_IB_NAME}\";"
        : "${V8_DB_SRV_DBMS:=MSSQLServer}"
        return 0
    fi
    IB_PATH="${dst_path}"
    if is_file_ib "${IB_PATH}"; then
        echo "[INFO] Destination type: File infobase (${IB_PATH})"
        V8_IB_CONNECTION="File=\"${IB_PATH}\";"
        return 0
    fi
    if [[ ! -e "${IB_PATH}" ]]; then
        echo "[INFO] Destination type: New file infobase (${IB_PATH})"
        V8_IB_CONNECTION="File=\"${IB_PATH}\";"
        mkdir -p "${IB_PATH}"
        return 0
    fi
    if [[ "${V8_IB_CREATE}" == "1" ]]; then
        echo "[INFO] Destination type: New file infobase (${IB_PATH})"
        V8_IB_CONNECTION="File=\"${IB_PATH}\";"
        [[ -d "${IB_PATH}" ]] && rm -rf "${IB_PATH}"
        mkdir -p "${IB_PATH}"
        return 0
    fi

    echo "[ERROR] Error cheking type of destination \"${dst_path}\"!"
    echo "Server or file infobase expected."
    ERROR_CODE=1
    return 1
}

# ============================================================
# parse_src_ib_path - parse source infobase connection
# Sets: IB_PATH, V8_IB_CONNECTION (or V8_IB_PATH), V8_IB_SERVER, V8_IB_NAME
# Returns: "file", "server", "file_existing", "" (error)
# ============================================================
parse_src_ib_path() {
    local src_path="${1}"
    local conn_var="${2:-V8_IB_CONNECTION}"

    local prefix="${src_path:0:2}"
    local prefix_lc="${prefix,,}"

    if [[ "${prefix_lc}" == "/f" ]]; then
        local ib_path="${src_path:2}"
        IB_PATH="${ib_path}"
        echo "[INFO] Source type: File infobase (${ib_path})"
        eval "${conn_var}=\"File=\\\"${ib_path}\\\";\""
        return 0
    fi
    if [[ "${prefix_lc}" == "/s" ]]; then
        local ib_path="${src_path:2}"
        IFS='\\/' read -r V8_IB_SERVER V8_IB_NAME <<< "${ib_path}"
        echo "[INFO] Source type: Server infobase (${V8_IB_SERVER}\\${V8_IB_NAME})"
        IB_PATH="${V8_IB_SERVER}\\${V8_IB_NAME}"
        eval "${conn_var}=\"Srvr=\\\"${V8_IB_SERVER}\\\";Ref=\\\"${V8_IB_NAME}\\\";\""
        : "${V8_DB_SRV_DBMS:=MSSQLServer}"
        return 0
    fi
    if is_file_ib "${src_path}"; then
        IB_PATH="${src_path}"
        echo "[INFO] Source type: File infobase (${src_path})"
        eval "${conn_var}=\"File=\\\"${src_path}\\\";\""
        return 0
    fi
    return 1
}

# ============================================================
# parse_base_ib - parse V8_BASE_IB for ext*/dp* scripts
# Sets: IB_PATH, V8_BASE_IB_CONNECTION, V8_BASE_IB_SERVER, V8_BASE_IB_NAME
# Returns 0 on success
# ============================================================
parse_base_ib() {
    local base_ib="${1:-}"

    if [[ -z "${base_ib}" ]]; then
        mkdir -p "${IB_PATH}"
        echo "[INFO] Using temporary file infobase \"${IB_PATH}\"..."
        V8_BASE_IB_CONNECTION="File=\"${IB_PATH}\";"
        V8_DESIGNER_LOG="${LOCAL_TEMP}/v8_designer_output.log"
        "${V8_TOOL}" CREATEINFOBASE "${V8_BASE_IB_CONNECTION}" /DisableStartupDialogs /Out "${V8_DESIGNER_LOG}"
        print_designer_log "${V8_DESIGNER_LOG}"
        return 0
    fi

    local prefix="${base_ib:0:2}"
    local prefix_lc="${prefix,,}"

    if [[ "${prefix_lc}" == "/f" ]]; then
        IB_PATH="${base_ib:2}"
        echo "[INFO] Basic infobase type: File infobase (${IB_PATH})"
        V8_BASE_IB_CONNECTION="File=\"${IB_PATH}\";"
        return 0
    fi
    if [[ "${prefix_lc}" == "/s" ]]; then
        IB_PATH="${base_ib:2}"
        IFS='\\/' read -r V8_BASE_IB_SERVER V8_BASE_IB_NAME <<< "${IB_PATH}"
        IB_PATH="${V8_BASE_IB_SERVER}\\${V8_BASE_IB_NAME}"
        echo "[INFO] Basic infobase type: Server infobase (${V8_BASE_IB_SERVER}\\${V8_BASE_IB_NAME})"
        V8_BASE_IB_CONNECTION="Srvr=\"${V8_BASE_IB_SERVER}\";Ref=\"${V8_BASE_IB_NAME}\";"
        : "${V8_DB_SRV_DBMS:=MSSQLServer}"
        return 0
    fi
    if is_file_ib "${base_ib}"; then
        IB_PATH="${base_ib}"
        echo "[INFO] Basic infobase type: File infobase (${IB_PATH})"
        V8_BASE_IB_CONNECTION="File=\"${IB_PATH}\";"
        return 0
    fi
    return 0
}

# ============================================================
# prepare_base_config - load base configuration into infobase
# ============================================================
prepare_base_config() {
    local base_config="${V8_BASE_CONFIG:-}"

    if [[ -z "${base_config}" ]]; then
        return 0
    fi

    [[ ! -d "${IB_PATH}" ]] && mkdir -p "${IB_PATH}"
    "${SCRIPT_DIR}/conf2ib.sh" "${base_config}" "${IB_PATH}"
    local rc=$?
    if [[ ${rc} -ne 0 ]]; then
        echo "[ERROR] Error cheking type of basic configuration \"${base_config}\"!"
        echo "File or server infobase, configuration file (*.cf), 1C:Designer XML, 1C:EDT project or no configuration expected."
        ERROR_CODE=1
        return 1
    fi
    return 0
}
