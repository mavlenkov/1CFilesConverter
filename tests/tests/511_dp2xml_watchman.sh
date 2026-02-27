#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Watchman trigger DP (binary folder) -> XML (using temp IB)"
TEST_OUT_PATH="${OUT_PATH}/$(basename "${BASH_SOURCE[0]}" .sh)"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH="${TEST_OUT_PATH}/src/ext/ВнешняяОбработка1.xml ${TEST_OUT_PATH}/src/ext/ВнешняяОбработка2.xml ${TEST_OUT_PATH}/src/ext/ВнешнийОтчет1.xml ${TEST_OUT_PATH}/src/ext/ВнешнийОтчет2.xml"

echo "==="
echo "Test ${TEST_COUNT}. ($(basename "${BASH_SOURCE[0]}" .sh)) ${TEST_NAME}"
echo "==="

V8_BASE_CONFIG="${FIXTURES_PATH}/bin/1cv8.cf"

mkdir -p "${TEST_OUT_PATH}/src"
mkdir -p "${TEST_OUT_PATH}/ext"

"${SCRIPTS_PATH}/../wmscripts/settrigger.sh" "Test_dp2xml" "${TEST_OUT_PATH}" 1cdpr dp2xml "${TEST_OUT_PATH}/src"

cp "${TEST_BINARY}"/*.epf "${TEST_OUT_PATH}/ext/" 2>/dev/null
cp "${TEST_BINARY}"/*.erf "${TEST_OUT_PATH}/ext/" 2>/dev/null

sleep 10

watchman trigger-del "${TEST_OUT_PATH}" Test_dp2xml
watchman watch-del "${TEST_OUT_PATH}"
