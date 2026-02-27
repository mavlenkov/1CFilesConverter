#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="DP (binary folder) -> XML (using existed IB)"
TEST_OUT_PATH="${OUT_PATH}/$(basename "${BASH_SOURCE[0]}" .sh)"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH="${TEST_OUT_PATH}/ВнешняяОбработка1.xml ${TEST_OUT_PATH}/ВнешняяОбработка2.xml ${TEST_OUT_PATH}/ВнешнийОтчет1.xml ${TEST_OUT_PATH}/ВнешнийОтчет2.xml"

echo "==="
echo "Test ${TEST_COUNT}. ($(basename "${BASH_SOURCE[0]}" .sh)) ${TEST_NAME}"
echo "==="
export V8_BASE_IB="${TEST_IB}"
"${SCRIPTS_PATH}/dp2xml.sh" "${FIXTURES_PATH}/bin" "${TEST_OUT_PATH}"
