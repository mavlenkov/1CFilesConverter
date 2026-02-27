#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Conf srerver infobase -> XML (ibcmd) with designer running"
TEST_OUT_PATH="${OUT_PATH}/$(basename "${BASH_SOURCE[0]}" .sh)"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH="${TEST_OUT_PATH}/Configuration.xml"
V8_PATH="/opt/1cv8/x86_64/${V8_VERSION}"
export V8_CONVERT_TOOL=ibcmd

echo "==="
echo "Test ${TEST_COUNT}. ($(basename "${BASH_SOURCE[0]}" .sh)) ${TEST_NAME}"
echo "==="

# Save existing 1cv8 PIDs
pids_1c_before=$(pgrep -f "1cv8" 2>/dev/null || true)

"${V8_PATH}/1cv8" DESIGNER /IBConnectionString "Srvr=\"${V8_SRV_ADDR}\";Ref=\"${V8_IB_NAME}\";" /DisableStartupDialogs &
DESIGNER_PID=$!
sleep 5

"${SCRIPTS_PATH}/conf2xml.sh" "/S${V8_DB_SRV_ADDR}/${V8_IB_NAME}" "${TEST_OUT_PATH}"

# Kill new 1cv8 processes (not in the original list)
pids_1c_after=$(pgrep -f "1cv8" 2>/dev/null || true)
for pid in ${pids_1c_after}; do
    is_new=1
    for old_pid in ${pids_1c_before}; do
        if [[ "${pid}" == "${old_pid}" ]]; then
            is_new=0
            break
        fi
    done
    if [[ "${is_new}" == "1" ]]; then
        kill -9 "${pid}" 2>/dev/null
    fi
done
