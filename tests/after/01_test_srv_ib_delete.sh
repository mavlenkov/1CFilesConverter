#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Delete test server infobase..."
TEST_OUT_PATH="${TEST_IB}"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH=""
V8_PATH="/opt/1cv8/x86_64/${V8_VERSION}"
RAC_TOOL="${V8_PATH}/rac"

echo "==="
echo "Clear ${TEST_COUNT}. ($(basename "${BASH_SOURCE[0]}" .sh)) ${TEST_NAME}"
echo "==="

echo "[INFO] Dropping temporary database \"${V8_DB_SRV_ADDR}/${V8_IB_NAME}\""

PGPASSWORD="${V8_DB_SRV_PWD}" psql -h "${V8_DB_SRV_ADDR}" -U "${V8_DB_SRV_USR}" -d postgres -c "DROP DATABASE IF EXISTS \"${V8_IB_NAME}\" WITH (FORCE);"

echo "[INFO] Looking for 1C cluster"

cluster_uuid=""
while IFS=' ' read -r line; do
    param_name="${line%%:*}"
    param_name="${param_name// /}"
    param_value="${line#*: }"
    param_value="${param_value// /}"
    param_value="${param_value//\"/}"
    if [[ "${param_name}" == "cluster" ]]; then
        cluster_uuid="${param_value}"
        echo "[INFO] Cluster UUID: ${cluster_uuid}"
        break
    fi
done < <("${RAC_TOOL}" "localhost:${V8_RAS_PORT}" cluster list 2>&1)

echo "[INFO] Looking for temporary infobase \"${V8_SRV_ADDR}/${V8_IB_NAME}\""

infobase_uuid=""
while IFS=' ' read -r line; do
    param_name="${line%%:*}"
    param_name="${param_name// /}"
    param_value="${line#*: }"
    param_value="${param_value// /}"
    param_value="${param_value//\"/}"
    if [[ "${param_name}" == "infobase" ]]; then
        infobase_uuid="${param_value}"
    fi
    if [[ "${param_name}" == "name" ]]; then
        ib_name_lower="${param_value,,}"
        v8_ib_lower="${V8_IB_NAME,,}"
        if [[ "${ib_name_lower}" == "${v8_ib_lower}" ]]; then
            echo "[INFO] Found infobase \"${V8_IB_NAME}\" UUID \"${infobase_uuid}\""
            break
        fi
    fi
done < <("${RAC_TOOL}" "localhost:${V8_RAS_PORT}" infobase summary list --cluster="${cluster_uuid}" 2>&1)

echo "[INFO] Dropping temporary infobase \"${V8_SRV_ADDR}/${V8_IB_NAME}\""

"${RAC_TOOL}" \
    "localhost:${V8_RAS_PORT}" \
    infobase drop \
    --cluster="${cluster_uuid}" \
    --infobase="${infobase_uuid}"

echo "[INFO] Killing RAS service"

# Kill new RAS processes (not in the original list)
pids_ras_after=$(pgrep -f "ras " 2>/dev/null || true)
for pid in ${pids_ras_after}; do
    is_new=1
    for old_pid in ${pids_ras}; do
        if [[ "${pid}" == "${old_pid}" ]]; then
            is_new=0
            break
        fi
    done
    if [[ "${is_new}" == "1" ]]; then
        kill -9 "${pid}" 2>/dev/null
    fi
done

echo "[INFO] Killing 1C:Enterprise Server agent"

# Kill new ragent processes (not in the original list)
pids_ragent_after=$(pgrep -f "ragent" 2>/dev/null || true)
for pid in ${pids_ragent_after}; do
    is_new=1
    for old_pid in ${pids_ragent}; do
        if [[ "${pid}" == "${old_pid}" ]]; then
            is_new=0
            break
        fi
    done
    if [[ "${is_new}" == "1" ]]; then
        kill -9 "${pid}" 2>/dev/null
    fi
done

sleep 10
