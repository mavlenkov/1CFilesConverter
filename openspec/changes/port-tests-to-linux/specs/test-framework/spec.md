## ADDED Requirements

### Requirement: Тестовый фреймворк test.sh
Скрипт test.sh SHALL повторять логику test.cmd: загрузка .env, создание каталогов out/, последовательный запуск скриптов из before/ → tests/ → after/, проверка TEST_CHECK_PATH для каждого теста, подсчёт и вывод результатов (SUCCESS/FAILED).

#### Scenario: Запуск полного набора тестов
- **WHEN** пользователь выполняет `./test.sh` из каталога tests/
- **THEN** фреймворк SHALL последовательно выполнить все .sh скрипты из before/, tests/, after/ в алфавитном порядке, проверить существование путей из TEST_CHECK_PATH для каждого теста и вывести итоговую статистику

#### Scenario: Тест считается успешным
- **WHEN** все пути из TEST_CHECK_PATH существуют и TEST_ERROR_MESSAGE пуст
- **THEN** фреймворк SHALL засчитать тест как SUCCESS и увеличить счётчик успешных тестов

#### Scenario: Тест считается провальным
- **WHEN** хотя бы один путь из TEST_CHECK_PATH не существует или TEST_ERROR_MESSAGE не пуст
- **THEN** фреймворк SHALL засчитать тест как FAILED, вывести отсутствующие пути и увеличить счётчик провальных тестов

### Requirement: Контракт тестового скрипта
Каждый тестовый скрипт (.sh) SHALL устанавливать переменные TEST_NAME, TEST_OUT_PATH, TEST_CHECK_PATH перед вызовом конвертационных скриптов. Опционально SHALL устанавливать TEST_ERROR_MESSAGE при обнаружении ошибки.

#### Scenario: Скрипт вызывается через source
- **WHEN** фреймворк вызывает тестовый скрипт через `source`
- **THEN** скрипт SHALL иметь доступ к переменным фреймворка (SCRIPTS_PATH, OUT_PATH, TEST_COUNT и др.) и SHALL устанавливать результирующие переменные (TEST_CHECK_PATH, TEST_ERROR_MESSAGE)

### Requirement: Адаптация серверных тестов для Linux
Серверные тесты SHALL использовать Linux-эквиваленты Windows-инструментов: pgrep/kill вместо tasklist/taskkill, Linux-пути для RAC/RAS. Удаление БД SHALL поддерживать несколько СУБД через ветвление по V8_DB_SRV_DBMS.

#### Scenario: Удаление базы данных PostgreSQL
- **WHEN** V8_DB_SRV_DBMS содержит "PostgreSQL" и требуется удалить тестовую БД
- **THEN** скрипт SHALL использовать psql для выполнения DROP DATABASE

#### Scenario: Удаление базы данных MSSQL
- **WHEN** V8_DB_SRV_DBMS содержит "MSSQLServer" и требуется удалить тестовую БД
- **THEN** скрипт SHALL использовать sqlcmd для выполнения DROP DATABASE

#### Scenario: Неизвестный тип СУБД
- **WHEN** V8_DB_SRV_DBMS не содержит известный тип СУБД
- **THEN** скрипт SHALL вывести предупреждение и пропустить удаление БД

#### Scenario: Управление процессами 1С
- **WHEN** тесту требуется найти или завершить процесс 1cv8 или ragent/ras
- **THEN** скрипт SHALL использовать pgrep для поиска и kill для завершения процессов
