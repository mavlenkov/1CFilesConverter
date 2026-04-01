## ADDED Requirements

### Requirement: Удалённый вызов ibcmd через SSH
Функция `run_ibcmd()` в common.sh SHALL выполнять ibcmd локально или удалённо через SSH в зависимости от наличия переменной `V8_REMOTE_HOST`. Первый аргумент — локальный путь к файлу/директории для передачи (пустая строка если передача не нужна). Остальные аргументы — команда ibcmd.

#### Scenario: Локальный вызов (V8_REMOTE_HOST не задан)
- **WHEN** переменная `V8_REMOTE_HOST` не задана или пуста
- **THEN** функция SHALL выполнить `"${IBCMD_TOOL}"` с переданными аргументами ibcmd, подставив локальный путь из первого аргумента как последний аргумент ibcmd (или в `--load=`/`--import=` для `infobase create`)

#### Scenario: Удалённый вызов (V8_REMOTE_HOST задан)
- **WHEN** переменная `V8_REMOTE_HOST` задана
- **THEN** функция SHALL скопировать файл/директорию на remote, выполнить ibcmd на remote через SSH с remote-путём, очистить remote temp и вернуть код возврата ibcmd

#### Scenario: Вызов без передачи файлов
- **WHEN** первый аргумент — пустая строка
- **THEN** функция SHALL выполнить ibcmd без передачи файлов (локально через `"${IBCMD_TOOL}"`, удалённо через SSH)

### Requirement: Передача файлов на remote
Функция `run_ibcmd()` SHALL копировать локальные файлы и директории на remote-хост при наличии непустого первого аргумента.

#### Scenario: Отправка одиночного файла
- **WHEN** первый аргумент — путь к существующему файлу и `V8_REMOTE_HOST` задан
- **THEN** функция SHALL скопировать файл через `scp` в уникальный подкаталог `V8_REMOTE_TEMP` и подставить remote-путь в аргументы ibcmd

#### Scenario: Отправка директории
- **WHEN** первый аргумент — путь к существующей директории и `V8_REMOTE_HOST` задан
- **THEN** функция SHALL рекурсивно скопировать директорию через `scp -r` в уникальный подкаталог `V8_REMOTE_TEMP` и подставить remote-путь в аргументы ibcmd

#### Scenario: Ошибка scp
- **WHEN** `scp` завершился с ненулевым кодом
- **THEN** функция SHALL вывести сообщение `[ERROR] Failed to copy files to remote host` и вернуть ненулевой код без вызова ibcmd

#### Scenario: Несуществующий локальный путь
- **WHEN** первый аргумент непустой, но файл/директория не существует
- **THEN** функция SHALL вывести сообщение об ошибке и вернуть ненулевой код

### Requirement: Уникальная рабочая директория на remote
Каждый вызов `run_ibcmd()` с `V8_REMOTE_HOST` SHALL использовать уникальный подкаталог в `V8_REMOTE_TEMP` для изоляции файлов и рабочих данных ibcmd (`--data`).

#### Scenario: Создание уникального подкаталога
- **WHEN** `V8_REMOTE_HOST` задан (независимо от наличия файлов для передачи)
- **THEN** функция SHALL создать подкаталог `V8_REMOTE_TEMP\run-<PID>-<TIMESTAMP>` на remote через SSH перед любыми операциями

#### Scenario: Параллельные запуски
- **WHEN** два вызова `run_ibcmd` выполняются одновременно
- **THEN** каждый SHALL использовать собственный уникальный подкаталог без взаимного влияния (включая изолированные `--data`)

### Requirement: Трансляция параметра --data
При удалённом вызове параметр `--data=` SHALL указывать на директорию внутри уникального подкаталога на remote-хосте.

#### Scenario: Замена --data при удалённом вызове
- **WHEN** среди аргументов ibcmd присутствует `--data=...` и `V8_REMOTE_HOST` задан
- **THEN** функция SHALL заменить значение `--data=` на `<unique_dir>\ibcmd_data` (внутри уникального подкаталога текущего вызова)

#### Scenario: --data при локальном вызове
- **WHEN** `V8_REMOTE_HOST` не задан
- **THEN** функция SHALL передать `--data=` без изменений

### Requirement: Очистка remote temp
Функция `run_ibcmd()` SHALL очищать уникальный подкаталог на remote после любого завершения, если подкаталог был создан.

#### Scenario: Очистка после успешного выполнения
- **WHEN** ibcmd завершился успешно на remote
- **THEN** функция SHALL удалить уникальный подкаталог из `V8_REMOTE_TEMP` через SSH

#### Scenario: Очистка после ошибки ibcmd
- **WHEN** ibcmd завершился с ошибкой на remote
- **THEN** функция SHALL удалить уникальный подкаталог и вернуть код ошибки ibcmd

#### Scenario: Очистка после ошибки scp
- **WHEN** scp завершился с ошибкой, но уникальный подкаталог уже создан на remote
- **THEN** функция SHALL удалить уникальный подкаталог перед возвратом ошибки

#### Scenario: Ошибка SSH при вызове ibcmd
- **WHEN** SSH-соединение не удалось при вызове ibcmd
- **THEN** функция SHALL вывести сообщение `[ERROR] SSH connection failed` и вернуть ненулевой код

### Requirement: Кодировка вывода на Windows
Функция `run_ibcmd()` SHALL обеспечивать корректную кодировку вывода ibcmd при удалённом вызове на Windows.

#### Scenario: Переключение кодировки перед ibcmd
- **WHEN** `V8_REMOTE_HOST` задан
- **THEN** функция SHALL выполнить `chcp 65001 >nul` перед ibcmd для переключения консоли Windows в UTF-8

### Requirement: Выполнение через cmd.exe на Windows
Функция `run_ibcmd()` SHALL формировать SSH-команду с учётом cmd.exe как оболочки на remote Windows-хосте.

#### Scenario: Путь к ibcmd.exe с пробелами
- **WHEN** `V8_REMOTE_IBCMD` содержит пробелы (например, `C:\Program Files\...`)
- **THEN** функция SHALL обернуть путь в двойные кавычки при формировании SSH-команды

#### Scenario: Аргументы ibcmd с пробелами
- **WHEN** аргументы ibcmd содержат пробелы (например, `--db-server="RIGEL\SQL2019"`)
- **THEN** функция SHALL корректно экранировать их для передачи через SSH → cmd.exe

### Requirement: Поддержка infobase create с файлом
Функция `run_ibcmd()` SHALL поддерживать команду `infobase create` с флагами `--load=` и `--import=`.

#### Scenario: infobase create --load с файлом
- **WHEN** аргументы ibcmd содержат `infobase create` и `--load=` (без значения после `=`)
- **THEN** функция SHALL дописать путь (локальный или remote) к значению `--load=`

#### Scenario: infobase create --import с директорией
- **WHEN** аргументы ibcmd содержат `infobase create` и `--import=` (без значения после `=`)
- **THEN** функция SHALL дописать путь (локальный или remote) к значению `--import=`

### Requirement: Формат scp-путей для Windows
Функция `run_ibcmd()` SHALL корректно формировать целевой путь scp для Windows-хоста.

#### Scenario: Копирование файла на Windows через scp
- **WHEN** функция копирует файл на remote Windows-хост
- **THEN** целевой путь SHALL передаваться в формате `host:'C:\path\to\dir\'` (Windows-путь в одинарных кавычках после двоеточия)

#### Scenario: Копирование директории на Windows через scp
- **WHEN** функция копирует директорию на remote Windows-хост
- **THEN** SHALL использоваться `scp -r` с тем же форматом целевого пути

### Requirement: Конфигурация удалённого вызова через переменные окружения
Удалённый вызов ibcmd SHALL настраиваться через переменные окружения.

#### Scenario: Значения по умолчанию
- **WHEN** `V8_REMOTE_HOST` задан, но `V8_REMOTE_IBCMD` и `V8_REMOTE_TEMP` не заданы
- **THEN** SHALL использоваться `C:\Program Files\1cv8\${V8_VERSION}\bin\ibcmd.exe` для `V8_REMOTE_IBCMD` и `C:\Temp\1c_conv` для `V8_REMOTE_TEMP`

#### Scenario: Пользовательские пути
- **WHEN** `V8_REMOTE_IBCMD` и/или `V8_REMOTE_TEMP` заданы явно
- **THEN** функция SHALL использовать указанные значения

#### Scenario: Логирование конфигурации remote
- **WHEN** `V8_REMOTE_HOST` задан и вызван `init_convert_tool()`
- **THEN** SHALL быть выведено `[INFO] Using remote ibcmd on ${V8_REMOTE_HOST}` с указанием путей
