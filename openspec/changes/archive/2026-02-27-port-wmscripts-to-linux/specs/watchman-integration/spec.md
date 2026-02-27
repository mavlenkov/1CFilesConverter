## ADDED Requirements

### Requirement: Bash-версии Watchman-скриптов
Каталог wmscripts/ SHALL содержать bash-эквиваленты (.sh) для convert.cmd и settrigger.cmd.

#### Scenario: Конвертация файлов через Watchman-триггер на Linux
- **WHEN** Watchman вызывает convert.sh с именем скрипта, путём источника и назначения, передавая список файлов через stdin
- **THEN** скрипт SHALL вызвать указанный конвертационный скрипт для каждого файла из stdin
