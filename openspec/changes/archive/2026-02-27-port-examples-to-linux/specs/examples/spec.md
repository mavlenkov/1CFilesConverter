## ADDED Requirements

### Requirement: Bash-версии примеров скриптов
Каталог examples/ SHALL содержать bash-эквиваленты (.sh) для каждого CMD-примера, повторяющие логику оригинала с адаптацией для Linux.

#### Scenario: Запуск примера на Linux
- **WHEN** пользователь выполняет любой `examples/*.sh` скрипт на Linux
- **THEN** скрипт SHALL выполнять ту же функциональность, что и соответствующий .cmd файл, используя Linux-пути и утилиты

### Requirement: Поддержка нескольких СУБД в create_ib.sh
Скрипт create_ib.sh SHALL поддерживать создание БД через ветвление по V8_DB_SRV_DBMS.

#### Scenario: Создание БД на MSSQL
- **WHEN** V8_DB_SRV_DBMS содержит "MSSQLServer"
- **THEN** скрипт SHALL использовать sqlcmd для восстановления БД из бэкапа

#### Scenario: Создание БД на PostgreSQL
- **WHEN** V8_DB_SRV_DBMS содержит "PostgreSQL"
- **THEN** скрипт SHALL использовать pg_restore или createdb для создания БД
