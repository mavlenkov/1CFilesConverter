#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

set -o pipefail

export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$(cd "${SCRIPT_DIR}/../scripts" && pwd)"
BEFORE_TEST_PATH="${SCRIPT_DIR}/before"
TEST_PATH="${SCRIPT_DIR}/tests"
AFTER_TEST_PATH="${SCRIPT_DIR}/after"
FIXTURES_PATH="${SCRIPT_DIR}/fixtures"

echo "[INFO] Clear output files..."

OUT_PATH="$(cd "${SCRIPT_DIR}/.." && pwd)/out"
rm -rf "${OUT_PATH}"
mkdir -p "${OUT_PATH}"

echo "[INFO] Prepare working directories..."

mkdir -p "${OUT_PATH}/data/ib"
mkdir -p "${OUT_PATH}/data/edt/cf"
mkdir -p "${OUT_PATH}/data/edt/ext"
mkdir -p "${OUT_PATH}/data/xml/cf"
mkdir -p "${OUT_PATH}/data/xml/ext"

# Load .env if exists
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "${key}" || "${key}" =~ ^# ]] && continue
        key="${key// /}"
        value="${value// /}"
        if [[ -z "${!key+x}" ]]; then
            export "${key}=${value}"
        fi
    done < "${SCRIPT_DIR}/.env"
fi

V8_VERSION="${V8_VERSION:-8.3.23.2040}"
V8_TEMP="${V8_TEMP:-${OUT_PATH}/tmp}"
export V8_VERSION V8_TEMP

mkdir -p "${V8_TEMP}"

TEST_BINARY="${FIXTURES_PATH}/bin"
TEST_IB="${OUT_PATH}/data/ib"
TEST_XML_CF="${OUT_PATH}/data/xml/cf"
TEST_XML_DP="${OUT_PATH}/data/xml/ext"
TEST_XML_EXT="${OUT_PATH}/data/xml/cfe"
TEST_EDT_CF="${OUT_PATH}/data/edt/cf"
TEST_EDT_DP="${OUT_PATH}/data/edt/ext"
TEST_EDT_EXT="${OUT_PATH}/data/edt/cfe"

TEST_COUNT=0
TEST_SUCCESS=0
TEST_FAILED=0
TEST_FAILED_LIST=""

TESTS_START="$(date '+%Y-%m-%d %H:%M:%S')"

# Function to run a phase (before/tests/after)
run_phase() {
    local phase_dir="$1"
    local phase_name="$2"

    echo "======"
    echo "${phase_name}"
    echo "======"

    for test_file in "${phase_dir}"/*.sh; do
        [[ -f "${test_file}" ]] || continue

        local test_basename
        test_basename="$(basename "${test_file}" .sh)"
        ((TEST_COUNT++))

        local test_start
        test_start="$(date '+%Y-%m-%d %H:%M:%S')"

        # Reset test variables
        TEST_CHECK_PATH=""
        TEST_ERROR_MESSAGE=""
        TEST_NAME=""
        TEST_OUT_PATH=""

        # Execute test script in current shell
        source "${test_file}"

        # Validate results
        local check_success=""
        local check_failed=""

        for check_path in ${TEST_CHECK_PATH}; do
            if [[ -e "${check_path}" ]]; then
                check_success="${check_success} ${check_path}"
            else
                check_failed="${check_failed} ${check_path}"
            fi
        done

        if [[ -n "${TEST_ERROR_MESSAGE}" ]]; then
            check_failed="${check_failed} ${TEST_ERROR_MESSAGE}"
        fi

        echo "==="
        echo "Start: ${test_start}"
        echo "Finish: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "==="

        if [[ -z "${check_failed}" ]]; then
            echo "[SUCCESS] Test SUCCESS (${test_basename})"
            ((TEST_SUCCESS++))
        else
            echo "[ERROR] Test FAILED (${test_basename}):"
            for path in ${check_failed}; do
                echo "    Path \"${path}\" not found"
            done
            for path in ${check_success}; do
                echo "    Path \"${path}\" exist"
            done
            TEST_FAILED_LIST="${TEST_FAILED_LIST} ${TEST_COUNT}:${test_basename}"
            ((TEST_FAILED++))
        fi
        echo "==="
        echo
    done
}

# Run phases
run_phase "${BEFORE_TEST_PATH}" "Prepare test data..."
run_phase "${TEST_PATH}" "Run tests..."
run_phase "${AFTER_TEST_PATH}" "Clear test data..."

# Cleanup
[[ -d "${V8_TEMP}" ]] && rm -rf "${V8_TEMP}"

# Results
echo "======"
echo "Test results:"
echo "======"
echo
echo "    Tests total: ${TEST_COUNT}"
echo "    Tests SUCCESS: ${TEST_SUCCESS}"
echo "    Tests FAILED: ${TEST_FAILED}"

for failed in ${TEST_FAILED_LIST}; do
    echo "        ${failed}"
done
echo "======"
echo "Start: ${TESTS_START}"
echo "Finish: $(date '+%Y-%m-%d %H:%M:%S')"
echo "======"
