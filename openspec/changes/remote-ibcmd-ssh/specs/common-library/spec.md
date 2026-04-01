## MODIFIED Requirements

### Requirement: Обнаружение инструментов конвертации
Функция `init_convert_tool()` SHALL определить доступный инструмент конвертации (Designer или ibcmd) на основании переменных окружения и наличия исполняемых файлов. При заданном `V8_REMOTE_HOST` проверка локального ibcmd SHALL пропускаться.

#### Scenario: Designer доступен по умолчанию
- **WHEN** переменная `V8_CONVERT_TOOL` не задана или равна `designer` и исполняемый файл Designer найден
- **THEN** функция SHALL настроить использование Designer для конвертации

#### Scenario: ibcmd выбран и доступен локально
- **WHEN** переменная `V8_CONVERT_TOOL` равна `ibcmd` и `V8_REMOTE_HOST` не задан и исполняемый файл ibcmd найден
- **THEN** функция SHALL настроить использование ibcmd для конвертации

#### Scenario: ibcmd выбран, remote-режим
- **WHEN** переменная `V8_CONVERT_TOOL` равна `ibcmd` и `V8_REMOTE_HOST` задан
- **THEN** функция SHALL пропустить проверку локального ibcmd, инициализировать `V8_REMOTE_IBCMD` и `V8_REMOTE_TEMP` со значениями по умолчанию (если не заданы), вывести `[INFO] Using remote ibcmd on ${V8_REMOTE_HOST}`

#### Scenario: ibcmd выбран, не найден и не remote
- **WHEN** переменная `V8_CONVERT_TOOL` равна `ibcmd` и `V8_REMOTE_HOST` не задан и исполняемый файл ibcmd не найден
- **THEN** функция SHALL завершить скрипт с ошибкой и сообщением о недоступности ibcmd

### Requirement: Обновление конфигурации БД
Функция `run_update_db()` SHALL выполнить обновление конфигурации базы данных только при явном запросе. При использовании ibcmd вызов SHALL выполняться через `run_ibcmd()`.

#### Scenario: Обновление включено, инструмент Designer
- **WHEN** переменная `V8_UPDATE_DB` равна `1` и `V8_CONVERT_TOOL` равна `designer`
- **THEN** функция SHALL выполнить Designer `/UpdateDBCfg` для указанной ИБ

#### Scenario: Обновление включено, инструмент ibcmd, серверная ИБ
- **WHEN** переменная `V8_UPDATE_DB` равна `1` и `V8_CONVERT_TOOL` не равна `designer` и задана `V8_IB_SERVER`
- **THEN** функция SHALL выполнить `run_ibcmd "" infobase config apply` с параметрами СУБД (пустой первый аргумент — без передачи файлов)

#### Scenario: Обновление включено, инструмент ibcmd, файловая ИБ
- **WHEN** переменная `V8_UPDATE_DB` равна `1` и `V8_CONVERT_TOOL` не равна `designer` и `V8_IB_SERVER` не задана
- **THEN** функция SHALL выполнить ibcmd локально с `--db-path` для файловой ИБ

#### Scenario: Обновление выключено
- **WHEN** переменная `V8_UPDATE_DB` не равна `1` или не задана
- **THEN** функция SHALL пропустить обновление конфигурации БД
