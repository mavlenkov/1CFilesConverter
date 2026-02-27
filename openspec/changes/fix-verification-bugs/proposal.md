## Why

При верификации спецификаций против реального кода обнаружены ошибки в bash-скриптах конвертации расширений. Скрипт ext2edt.sh содержит ошибку портирования: при XML-источнике выполняется лишний вызов `/LoadCfg` на каталог XML (в оригинальном CMD этот шаг пропускается через `goto export_xml`). Скрипт ext2xml.sh содержит аналогичную проблему для EDT-источника (унаследованную из CMD-оригинала): `/LoadCfg` вызывается на каталог EDT-проекта перед корректным `run_edt_export`.

## What Changes

- Исправить ext2edt.sh: XML-источник SHALL пропускать блок LoadCfg и переходить сразу к EDT-импорту (как в CMD-оригинале)
- Исправить ext2xml.sh: EDT-источник SHALL пропускать блок LoadCfg и переходить сразу к EDT-экспорту (улучшение относительно CMD-оригинала)

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities
- `extension-conversion`: Исправление цепочек конвертации для EDT→XML и XML→EDT — блок LoadCfg SHALL выполняться только для CFE-источника

## Impact

- `scripts/ext2edt.sh` — изменение условия входа в блок load_cfe (porting bug fix)
- `scripts/ext2xml.sh` — изменение условия входа в блок load_cfe (improvement over CMD)
- CMD-скрипты не затрагиваются
