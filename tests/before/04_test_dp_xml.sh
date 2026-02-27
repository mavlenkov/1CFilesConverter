#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Prepare data processors & reports with 1C:Designer XML format..."
TEST_OUT_PATH="${TEST_XML_DP}"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH="${TEST_OUT_PATH}/ВнешняяОбработка1.xml ${TEST_OUT_PATH}/ВнешняяОбработка2.xml ${TEST_OUT_PATH}/ВнешнийОтчет1.xml ${TEST_OUT_PATH}/ВнешнийОтчет2.xml"

echo "==="
echo "Prepare ${TEST_COUNT}. ($(basename "$0" .sh)) ${TEST_NAME}"
echo "==="

"${SCRIPTS_PATH}/dp2xml.sh" "${TEST_BINARY}" "${TEST_OUT_PATH}" "${TEST_IB}"
