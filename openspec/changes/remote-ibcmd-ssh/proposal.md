## Why

ibcmd на Linux не поддерживает СУБД MSSQLServer — это ограничение платформы 1С. При этом ibcmd на Windows (rigel) работает с MSSQL и доступен по SSH. Чтобы использовать ibcmd для серверных ИБ на MSSQL с Linux-рабочей станции, нужна прозрачная обёртка, которая выполняет ibcmd удалённо через SSH. Это критически важно, потому что Designer (альтернатива) работает значительно медленнее.

## What Changes

- Добавить функцию `run_ibcmd()` в `scripts/common.sh`, которая:
  - Без `V8_REMOTE_HOST` — вызывает ibcmd локально (текущее поведение, без регрессий)
  - С `V8_REMOTE_HOST` — копирует входные файлы/директории на remote через scp, выполняет ibcmd по SSH, очищает remote temp
- Заменить прямые вызовы `"${IBCMD_TOOL}" infobase ...` на `run_ibcmd` в:
  - `scripts/common.sh` — функция `run_update_db()` (config apply)
  - `scripts/conf2ib.sh` — загрузка конфигурации (config load, config import, infobase create)
  - `scripts/ext2ib.sh` — загрузка расширения (config load, config import)
- Ослабить проверку локального ibcmd в `init_convert_tool()` при заданном `V8_REMOTE_HOST`
- Добавить новые переменные окружения: `V8_REMOTE_HOST`, `V8_REMOTE_IBCMD`, `V8_REMOTE_TEMP`

**Scope первой версии:** только загрузка (load, import, create) и применение (apply). Выгрузка (save, export) через remote — отдельная доработка в будущем.

## Capabilities

### New Capabilities
- `remote-ibcmd`: Прозрачный удалённый вызов ibcmd через SSH с автоматической передачей файлов (scp) и трансляцией путей

### Modified Capabilities
- `common-library`: Добавление функции `run_ibcmd()`, ослабление проверки локального ibcmd при remote-режиме, замена прямых вызовов ibcmd в `run_update_db()`

## Impact

- `scripts/common.sh` — новая функция `run_ibcmd()`, модификация `init_convert_tool()` и `run_update_db()`
- `scripts/conf2ib.sh` — замена прямых вызовов ibcmd на `run_ibcmd` в ветках серверных ИБ
- `scripts/ext2ib.sh` — замена прямых вызовов ibcmd на `run_ibcmd` в ветках серверных ИБ
- Новая зависимость: SSH-доступ к удалённому хосту с аутентификацией по ключу (опционально, только при V8_REMOTE_HOST)
- Обратная совместимость: без V8_REMOTE_HOST поведение идентично текущему
