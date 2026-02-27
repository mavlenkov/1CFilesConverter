#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Script parameters error"

echo "==="
echo "Test ${TEST_COUNT}. ($(basename "${BASH_SOURCE[0]}" .sh)) ${TEST_NAME}"
echo "==="
"${SCRIPTS_PATH}/conf2cf.sh"

if [[ $? -eq 0 ]]; then
    TEST_ERROR_MESSAGE="Failed parameter check!"
fi
