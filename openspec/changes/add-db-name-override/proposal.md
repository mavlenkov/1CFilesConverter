# Добавить переменную V8_DB_NAME для указания имени БД в СУБД

## Проблема

При использовании `ibcmd` для серверных ИБ имя базы данных в СУБД (`--db-name`) берётся из `V8_IB_NAME`, которое парсится из строки подключения `/S сервер\ИмяИБ`. Но имя ИБ в кластере 1С и имя БД в СУБД могут отличаться.

Пример: ИБ `Фидес` в кластере → БД `Fides` в PostgreSQL.

Текущий результат: `ibcmd` получает `--db-name=Фидес` и падает с ошибкой `база данных "Фидес" не существует`.

## Корневая причина

`scripts/common.sh`, строка 480 — `V8_IB_NAME` безусловно перезаписывается парсингом строки подключения:

```bash
IFS='\\/' read -r V8_IB_SERVER V8_IB_NAME <<< "${IB_PATH}"
```

Затем `V8_IB_NAME` используется как `--db-name` во всех вызовах `ibcmd` (строка 420 и аналогичные в `conf2ib.sh`, `conf2xml.sh`, `conf2edt.sh`, `conf2cf.sh`, `ext2ib.sh` — как `.sh` так и `.cmd` варианты).

## Предлагаемое решение

Добавить переменную окружения `V8_DB_NAME` — явное имя базы данных в СУБД. Если задана — использовать её как `--db-name`. Если не задана — fallback на `V8_IB_NAME` (текущее поведение, обратная совместимость).

### Изменения в `common.sh`

В функции `update_ib_config`, строка 420:
```bash
# Было:
ibcmd_args+=(... --db-name="${V8_IB_NAME}" ...)

# Стало:
ibcmd_args+=(... --db-name="${V8_DB_NAME:-${V8_IB_NAME}}" ...)
```

### Затронутые файлы

Все файлы где встречается `--db-name="${V8_IB_NAME}"`:

**Linux (.sh):**
- `scripts/common.sh` (стр. 420)
- `scripts/conf2ib.sh` (стр. 74, 77, 138, 141)
- `scripts/conf2xml.sh` (стр. 63, 136)
- `scripts/conf2edt.sh` (стр. 65, 125)
- `scripts/conf2cf.sh` (стр. 134)
- `scripts/ext2ib.sh` (стр. 108, 134, 160)

**Windows (.cmd):**
- `scripts/conf2ib.cmd` (стр. 222, 225, 256, 259)
- `scripts/conf2xml.cmd` (стр. 143, 164)
- `scripts/conf2edt.cmd` (стр. 147, 171)
- `scripts/conf2cf.cmd` (стр. 209)
- `scripts/ext2ib.cmd` (стр. 216, 234)

Замена одинаковая везде: `${V8_IB_NAME}` → `${V8_DB_NAME:-${V8_IB_NAME}}` (для .sh) и `%V8_IB_NAME%` → проверка `if defined V8_DB_NAME` (для .cmd).

## Использование

```bash
# ИБ "Фидес", БД в PostgreSQL "Fides"
V8_DB_NAME=Fides \
V8_CONVERT_TOOL=ibcmd \
V8_DB_SRV_DBMS=PostgreSQL \
V8_DB_SRV_ADDR=alcor \
V8_DB_SRV_USR=postgres \
V8_DB_SRV_PWD=secret \
  ./scripts/conf2ib.sh . '/Salcor:1541\Фидес'
```

## Обратная совместимость

Полная. Если `V8_DB_NAME` не задана — поведение не меняется.
