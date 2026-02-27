## Why

Каталог `examples/` содержит 14 CMD-скриптов — примеры типовых сценариев работы с конвертацией файлов 1С. Linux-версий нет. Для пользователей Linux нужны bash-эквиваленты, использующие те же паттерны, что уже применяются в `scripts/*.sh`.

## What Changes

- Портировать все 14 CMD-скриптов из `examples/` в bash (.sh)
- Адаптировать `create_ib.sh` с ветвлением по V8_DB_SRV_DBMS (MSSQL/PostgreSQL)
- Использовать паттерны из `scripts/common.sh` (load_env, пути, переменные)

## Capabilities

### New Capabilities

(нет — это портирование существующих примеров, не новая функциональность)

### Modified Capabilities

(нет)

## Impact

- 14 новых файлов `examples/*.sh`
- Не затрагивает существующие `scripts/*.sh` и `tests/*.sh`
