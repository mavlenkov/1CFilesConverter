#!/bin/bash

export LC_ALL=C.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RELATIVE_SRC_PATH="src"

REPO_PATH="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SRC_PATH="${REPO_PATH}/${RELATIVE_SRC_PATH}"

if [[ ! -d "${SRC_PATH}" ]]; then
    echo "[ERROR] Path to source files \"${SRC_PATH}\" not found"
    exit 1
fi

if [[ -f "${REPO_PATH}/.env" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "${key}" || "${key}" =~ ^# ]] && continue
        if [[ -z "${!key+x}" ]]; then
            export "${key}=${value}"
        fi
    done < "${REPO_PATH}/.env"
fi

if [[ "${V8_SRC_TYPE,,}" == "edt" ]]; then
    RELATIVE_CF_PATH="main"
else
    RELATIVE_CF_PATH="cf"
    RELATIVE_CFE_PATH="cfe"
fi

if [[ -z "${V8_TOOL+x}" ]]; then
    V8_TOOL="/opt/1cv8/x86_64/${V8_VERSION}/bin/1cv8"
fi

# Database backup/restore path variables (override via .env or environment)
if [[ -z "${V8_DB_BACKUP_PATH+x}" ]]; then
    V8_DB_BACKUP_PATH="/var/lib/1c/backup"
fi
if [[ -z "${V8_DB_DATA_PATH+x}" ]]; then
    V8_DB_DATA_PATH="/var/lib/1c/data"
fi
if [[ -z "${V8_DB_LOG_PATH+x}" ]]; then
    V8_DB_LOG_PATH="/var/lib/1c/log"
fi

echo "START: $(date '+%Y-%m-%d %H:%M:%S')"

echo "Create database ${V8_IB_NAME}"

# DBMS branching: restore/create database depending on DBMS type
if [[ "${V8_DB_SRV_DBMS}" == *"MSSQLServer"* ]]; then
    # Microsoft SQL Server: use sqlcmd to restore from backup
    if [[ -z "${V8_IB_TEMPLATE+x}" ]]; then
        echo "[ERROR] V8_IB_TEMPLATE is not defined for MSSQL restore"
        exit 1
    fi
    QUERY="RESTORE DATABASE [${V8_IB_NAME}] FROM  DISK = N'${V8_DB_BACKUP_PATH}/${V8_IB_TEMPLATE}.bak' WITH  FILE = 1,  MOVE N'Temlate_ERP_2_5_12' TO N'${V8_DB_DATA_PATH}/${V8_IB_NAME}.mdf', MOVE N'Temlate_ERP_2_5_12_log' TO N'${V8_DB_LOG_PATH}/${V8_IB_NAME}_log.ldf',  NOUNLOAD,  REPLACE,  STATS = 5"
    sqlcmd -S "${V8_DB_SRV_ADDR}" -U "${V8_DB_SRV_USR}" -P "${V8_DB_SRV_PWD}" -d master -Q "${QUERY}"

elif [[ "${V8_DB_SRV_DBMS}" == *"PostgreSQL"* ]]; then
    # PostgreSQL: create database (or restore from backup if template exists)
    export PGPASSWORD="${V8_DB_SRV_PWD}"
    if [[ -n "${V8_IB_TEMPLATE+x}" ]] && [[ -f "${V8_DB_BACKUP_PATH}/${V8_IB_TEMPLATE}.dump" ]]; then
        echo "[INFO] Restoring PostgreSQL database from backup ${V8_DB_BACKUP_PATH}/${V8_IB_TEMPLATE}.dump"
        createdb -h "${V8_DB_SRV_ADDR}" -U "${V8_DB_SRV_USR}" "${V8_IB_NAME}"
        pg_restore -h "${V8_DB_SRV_ADDR}" -U "${V8_DB_SRV_USR}" -d "${V8_IB_NAME}" "${V8_DB_BACKUP_PATH}/${V8_IB_TEMPLATE}.dump"
    else
        echo "[INFO] Creating empty PostgreSQL database ${V8_IB_NAME}"
        createdb -h "${V8_DB_SRV_ADDR}" -U "${V8_DB_SRV_USR}" "${V8_IB_NAME}"
    fi
    unset PGPASSWORD

else
    echo "[WARN] Unknown or unsupported DBMS type: ${V8_DB_SRV_DBMS}"
    echo "[WARN] Skipping database creation. Create the database manually before proceeding."
fi

sleep 10

echo "[INFO] CREATE INFOBASE ON ${V8_SRV_ADDR}:${V8_SRV_CLUSTER_PORT:-1541} WITH NAME ${V8_IB_NAME}"
"${V8_TOOL}" CREATEINFOBASE "Srvr=\"${V8_SRV_ADDR}:${V8_SRV_CLUSTER_PORT:-1541}\";Ref=\"${V8_IB_NAME}\";DBMS=\"${V8_DB_SRV_DBMS,,}\";DBSrvr=\"${V8_DB_SRV_ADDR}\";DB=\"${V8_IB_NAME}\";DBUID=\"${V8_DB_SRV_USR}\";DBPwd=\"${V8_DB_SRV_PWD}\";LicDstr=\"Y\";CrSQLDB=\"N\";SchJobDn=\"Y\";"
echo "INFOBASE CREATED."

echo "FINISHED: $(date '+%Y-%m-%d %H:%M:%S')"
