## ADDED Requirements

### Requirement: Фиксация окончаний строк через .gitattributes
Репозиторий SHALL содержать файл `.gitattributes`, гарантирующий корректные окончания строк для скриптов независимо от локальных настроек git.

#### Scenario: Checkout .sh файла на Windows
- **WHEN** пользователь с `core.autocrlf=true` клонирует репозиторий
- **THEN** все `.sh` файлы SHALL иметь LF-окончания строк

#### Scenario: Checkout .cmd файла на Linux
- **WHEN** пользователь на Linux клонирует репозиторий
- **THEN** все `.cmd` файлы SHALL иметь CRLF-окончания строк
