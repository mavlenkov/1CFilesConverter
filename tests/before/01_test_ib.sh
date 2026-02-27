#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Prepare test infobase..."
TEST_OUT_PATH="${TEST_IB}"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH="${TEST_OUT_PATH}/1Cv8.1CD"

echo "==="
echo "Prepare ${TEST_COUNT}. ($(basename "$0" .sh)) ${TEST_NAME}"
echo "==="

"${SCRIPTS_PATH}/conf2ib.sh" "${TEST_BINARY}/1cv8.cf" "${TEST_OUT_PATH}" create
