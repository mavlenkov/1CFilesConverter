#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Prepare test server infobase..."
TEST_OUT_PATH="${TEST_IB}"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH=""
V8_PATH="/opt/1cv8/x86_64/${V8_VERSION}/bin"
IBCMD_TOOL="${V8_PATH}/ibcmd"
RAC_TOOL="${V8_PATH}/rac"

echo "==="
echo "Prepare ${TEST_COUNT}. ($(basename "$0" .sh)) ${TEST_NAME}"
echo "==="

echo "[INFO] Starting 1C:Enterprise Server agent"

# Remember ragent PIDs before starting a new one
pids_ragent_before=""
while read -r pid; do
    if [[ -z "${pids_ragent_before}" ]]; then
        pids_ragent_before="${pid}"
    else
        pids_ragent_before="${pids_ragent_before},${pid}"
    fi
done < <(pgrep -f ragent)

(cd "${V8_PATH}" && ./ragent -agent -regport "${V8_SRV_REG_PORT}" -port "${V8_SRV_AGENT_PORT}" -range "${V8_SRV_PORT_RANGE}" -d "${V8_TEMP}/srvinfo${V8_SRV_REG_PORT}" &)

sleep 10

echo "[INFO] Starting RAS service"

# Remember ras PIDs before starting a new one
pids_ras_before=""
while read -r pid; do
    if [[ -z "${pids_ras_before}" ]]; then
        pids_ras_before="${pid}"
    else
        pids_ras_before="${pids_ras_before},${pid}"
    fi
done < <(pgrep -f "ras ")

(cd "${V8_PATH}" && ./ras cluster --port="${V8_RAS_PORT}" "${V8_SRV_ADDR}:${V8_SRV_AGENT_PORT}" &)

sleep 10

echo "[INFO] Looking for 1C cluster"

cluster_uuid=""
while IFS=':' read -r param_name param_value; do
    param_name="${param_name// /}"
    if [[ "${param_name}" == "cluster" ]]; then
        param_value="${param_value// /}"
        param_value="${param_value//\"/}"
        cluster_uuid="${param_value}"
        echo "[INFO] Cluster UUID: ${cluster_uuid}"
        break
    fi
done < <("${RAC_TOOL}" "localhost:${V8_RAS_PORT}" cluster list)

echo "[INFO] Creating temporary infobase \"${V8_SRV_ADDR}:${V8_SRV_REG_PORT}/${V8_IB_NAME}\""

"${RAC_TOOL}" \
    "localhost:${V8_RAS_PORT}" \
    infobase create \
    --cluster="${cluster_uuid}" \
    --create-database \
    --name="${V8_IB_NAME}" \
    --dbms="${V8_DB_SRV_DBMS}" \
    --db-server="${V8_DB_SRV_ADDR}" \
    --db-name="${V8_IB_NAME}" \
    --db-user="${V8_DB_SRV_USR}" \
    --db-pwd="${V8_DB_SRV_PWD}" \
    --locale=ru_RU \
    --descr="Temp infobase for 1C files converter tests" \
    --date-offset=2000 \
    --scheduled-jobs-deny=on \
    --license-distribution=allow

echo "[INFO] Loading config \"${TEST_BINARY}/1cv8.cf\" to database \"${V8_DB_SRV_ADDR}/${V8_IB_NAME}\""

"${IBCMD_TOOL}" infobase config load \
    --dbms="${V8_DB_SRV_DBMS}" \
    --db-server="${V8_DB_SRV_ADDR}" \
    --db-name="${V8_IB_NAME}" \
    --db-user="${V8_DB_SRV_USR}" \
    --db-pwd="${V8_DB_SRV_PWD}" \
    --force \
    "${TEST_BINARY}/1cv8.cf"
