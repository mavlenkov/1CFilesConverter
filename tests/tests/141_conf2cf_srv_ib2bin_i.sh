#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Conf server infobase -> CF (ibcmd)"
TEST_OUT_PATH="${OUT_PATH}/$(basename "${BASH_SOURCE[0]}" .sh)/1cv8.cf"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH="${TEST_OUT_PATH}"
export V8_CONVERT_TOOL=ibcmd

echo "==="
echo "Test ${TEST_COUNT}. ($(basename "${BASH_SOURCE[0]}" .sh)) ${TEST_NAME}"
echo "==="
"${SCRIPTS_PATH}/conf2cf.sh" "/S${V8_DB_SRV_ADDR}/${V8_IB_NAME}" "${TEST_OUT_PATH}"
