#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Ext EDT -> CFE (designer)"
TEST_EXT_NAME=Расширение1
TEST_OUT_PATH="${OUT_PATH}/$(basename "${BASH_SOURCE[0]}" .sh)/${TEST_EXT_NAME}.cfe"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH="${TEST_OUT_PATH}"
export V8_CONVERT_TOOL=designer

echo "==="
echo "Test ${TEST_COUNT}. ($(basename "${BASH_SOURCE[0]}" .sh)) ${TEST_NAME}"
echo "==="
export V8_BASE_CONFIG="${TEST_BINARY}/1cv8.cf"
"${SCRIPTS_PATH}/ext2cfe.sh" "${TEST_EDT_EXT}/${TEST_EXT_NAME}" "${TEST_OUT_PATH}" "${TEST_EXT_NAME}"
