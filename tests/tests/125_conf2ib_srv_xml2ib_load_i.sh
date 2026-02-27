#!/bin/bash
# ----------------------------------------------------------
# This Source Code Form is subject to the terms of the
# Mozilla Public License, v.2.0. If a copy of the MPL
# was not distributed with this file, You can obtain one
# at http://mozilla.org/MPL/2.0/.
# ----------------------------------------------------------
# Codebase: https://github.com/ArKuznetsov/1CFilesConverter/
# ----------------------------------------------------------

TEST_NAME="Conf XML -> load to server infobase (ibcmd)"
TEST_OUT_PATH="${OUT_PATH}/$(basename "${BASH_SOURCE[0]}" .sh)"
TEST_OUT_PATH="${TEST_OUT_PATH// /_}"
TEST_CHECK_PATH="${TEST_OUT_PATH}/Catalogs/Контрагенты.xml"
V8_PATH="/opt/1cv8/x86_64/${V8_VERSION}"
RAC_TOOL="${V8_PATH}/rac"
export V8_CONVERT_TOOL=ibcmd

echo "==="
echo "Test ${TEST_COUNT}. ($(basename "${BASH_SOURCE[0]}" .sh)) ${TEST_NAME}"
echo "==="

TMP_IB_NAME="TMP_IB_$(basename "${BASH_SOURCE[0]}" .sh)"
TMP_IB_NAME="${TMP_IB_NAME// /_}"

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

echo "[INFO] Creating temporary infobase \"${V8_SRV_ADDR}/${TMP_IB_NAME}\""

"${RAC_TOOL}" \
    "localhost:${V8_RAS_PORT}" \
    infobase create \
    --cluster="${cluster_uuid}" \
    --create-database \
    --name="${TMP_IB_NAME}" \
    --dbms="${V8_DB_SRV_DBMS}" \
    --db-server="${V8_DB_SRV_ADDR}" \
    --db-name="${TMP_IB_NAME}" \
    --db-user="${V8_DB_SRV_USR}" \
    --db-pwd="${V8_DB_SRV_PWD}" \
    --locale=ru_RU \
    --descr="Temp infobase for 1C files converter tests" \
    --date-offset=2000 \
    --scheduled-jobs-deny=on \
    --license-distribution=allow

"${SCRIPTS_PATH}/conf2ib.sh" "${TEST_XML_CF}" "/S${V8_DB_SRV_ADDR}/${TMP_IB_NAME}"

"${SCRIPTS_PATH}/conf2xml.sh" "/S${V8_DB_SRV_ADDR}/${TMP_IB_NAME}" "${TEST_OUT_PATH}"

echo "[INFO] Dropping temporary database \"${V8_DB_SRV_ADDR}/${TMP_IB_NAME}\""

V8_DB_SRV_DBMS_LOWER="${V8_DB_SRV_DBMS,,}"
if [[ "${V8_DB_SRV_DBMS_LOWER}" == *"postgres"* ]]; then
    PGPASSWORD="${V8_DB_SRV_PWD}" psql -h "${V8_DB_SRV_ADDR}" -U "${V8_DB_SRV_USR}" -d postgres -c "DROP DATABASE IF EXISTS \"${TMP_IB_NAME}\" WITH (FORCE);"
elif [[ "${V8_DB_SRV_DBMS_LOWER}" == *"mssql"* ]]; then
    sqlcmd -S "${V8_DB_SRV_ADDR}" -U "${V8_DB_SRV_USR}" -P "${V8_DB_SRV_PWD}" -Q "USE [master]; ALTER DATABASE [${TMP_IB_NAME}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [${TMP_IB_NAME}]" -b -y 0
else
    echo "[WARNING] Unknown DBMS type \"${V8_DB_SRV_DBMS}\", skipping database drop"
fi

echo "[INFO] Looking for temporary infobase \"${V8_SRV_ADDR}/${TMP_IB_NAME}\""

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
        tmp_ib_lower="${TMP_IB_NAME,,}"
        if [[ "${ib_name_lower}" == "${tmp_ib_lower}" ]]; then
            echo "[INFO] Found infobase \"${TMP_IB_NAME}\" UUID \"${infobase_uuid}\""
            break
        fi
    fi
done < <("${RAC_TOOL}" "localhost:${V8_RAS_PORT}" infobase summary list --cluster="${cluster_uuid}" 2>&1)

echo "[INFO] Dropping temporary infobase \"${V8_SRV_ADDR}/${TMP_IB_NAME}\""

"${RAC_TOOL}" \
    "localhost:${V8_RAS_PORT}" \
    infobase drop \
    --cluster="${cluster_uuid}" \
    --infobase="${infobase_uuid}"
