## Why

Каталог `wmscripts/` содержит 2 CMD-скрипта для интеграции с Watchman (файловый наблюдатель). Linux-версий нет. Watchman работает на Linux нативно, но скрипты-обработчики (`convert.cmd`, `settrigger.cmd`) — только Windows. Нужны bash-эквиваленты.

## What Changes

- Портировать `convert.cmd` → `convert.sh` (обёртка конвертации, читает файлы из stdin)
- Портировать `settrigger.cmd` → `settrigger.sh` (настройка триггера Watchman)
- Обновить JSON-примеры: добавить Linux-варианты с `.sh` вместо `.cmd`

## Capabilities

### New Capabilities

(нет — портирование существующей функциональности)

### Modified Capabilities

(нет)

## Impact

- 2 новых файла: `wmscripts/convert.sh`, `wmscripts/settrigger.sh`
- Опционально: обновление или дополнение JSON-примеров Linux-путями
