## Context

Watchman — кроссплатформенный инструмент. JSON-протокол одинаков на Windows и Linux. Различаются только скрипты-обработчики (CMD vs bash) и пути.

## Goals / Non-Goals

**Goals:**
- Создать bash-эквиваленты convert.cmd и settrigger.cmd
- Сохранить полную совместимость с Watchman JSON API

**Non-Goals:**
- Изменение логики работы скриптов
- Портирование самого Watchman (он уже кроссплатформенный)

## Decisions

**1. Поиск watchman** — `which watchman` вместо `where watchman`.

**2. Поиск скрипта конвертации** — если скрипт не найден по полному пути, ищем `scripts/<name>.sh` (вместо `.cmd`).

**3. JSON-примеры** — добавить `trigger_example_linux.json` и `watch_example_linux.json` с Linux-путями и `.sh` вместо `.cmd`. Оригиналы не менять.

**4. Пути в JSON** — на Linux не нужна замена `\` → `\\` (используем `/` напрямую).

## Risks / Trade-offs

- [Watchman может быть не установлен] → Скрипт уже проверяет наличие watchman и выводит ошибку.
