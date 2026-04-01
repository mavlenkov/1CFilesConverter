## 1. Функция run_ibcmd в common.sh

- [x] 1.1 Добавить функцию `run_ibcmd()`: первый аргумент — локальный путь (или пустая строка), остальные — аргументы ibcmd
- [x] 1.2 Реализовать локальный режим: при отсутствии `V8_REMOTE_HOST` вызывать `"${IBCMD_TOOL}"` с подстановкой пути как последнего аргумента (или в `--load=`/`--import=` для `infobase create`)
- [x] 1.3 Реализовать создание уникального подкаталога на remote: `V8_REMOTE_TEMP\run-<PID>-<TIMESTAMP>` через ssh mkdir (для всех remote-вызовов, включая apply без файлов)
- [x] 1.4 Реализовать scp отправки файла/директории в уникальный подкаталог на remote (формат пути: `host:'C:\path\'`)
- [x] 1.5 Реализовать трансляцию `--data=` на путь внутри уникального подкаталога: `<unique_dir>\ibcmd_data`
- [x] 1.6 Реализовать формирование SSH-команды: `chcp 65001 >nul &` + путь к ibcmd.exe в кавычках + аргументы с корректным экранированием для cmd.exe
- [x] 1.7 Реализовать подстановку remote-пути в аргументы ibcmd (последний аргумент или `--load=`/`--import=`)
- [x] 1.8 Реализовать очистку уникального подкаталога на remote после любого завершения: успех ibcmd, ошибка ibcmd, ошибка scp (если mkdir уже выполнен)
- [x] 1.9 Добавить обработку ошибок scp и ssh с диагностическими сообщениями
- [x] 1.10 Добавить обработку ошибки создания remote-каталога (ssh mkdir)

## 2. Инициализация remote-переменных в init_convert_tool

- [x] 2.1 При `V8_REMOTE_HOST` задан и `V8_CONVERT_TOOL=ibcmd`: пропустить проверку локального `IBCMD_TOOL`
- [x] 2.2 Инициализировать `V8_REMOTE_IBCMD` и `V8_REMOTE_TEMP` со значениями по умолчанию
- [x] 2.3 Вывести `[INFO] Using remote ibcmd on ${V8_REMOTE_HOST}` с путями

## 3. Интеграция в conf2ib.sh

- [x] 3.1 Заменить вызовы `"${IBCMD_TOOL}" infobase config load` для серверных ИБ на `run_ibcmd`
- [x] 3.2 Заменить вызовы `"${IBCMD_TOOL}" infobase config import` для серверных ИБ на `run_ibcmd`
- [x] 3.3 Заменить вызовы `"${IBCMD_TOOL}" infobase create --load=`/`--import=` для серверных ИБ на `run_ibcmd`

## 4. Интеграция в ext2ib.sh

- [x] 4.1 Заменить вызовы `"${IBCMD_TOOL}" infobase config load` для серверных ИБ на `run_ibcmd`
- [x] 4.2 Заменить вызовы `"${IBCMD_TOOL}" infobase config import` для серверных ИБ на `run_ibcmd`

## 5. Интеграция в common.sh (run_update_db)

- [x] 5.1 Заменить вызов `"${IBCMD_TOOL}" infobase config apply` для серверных ИБ в `run_update_db()` на `run_ibcmd "" infobase config apply ...`

## 6. Тестирование

- [x] 6.1 Проверить загрузку конфигурации CF в серверную ИБ через remote ibcmd (`conf2ib.sh`, config load)
- [x] 6.2 Проверить загрузку конфигурации XML в серверную ИБ через remote ibcmd (`conf2ib.sh`, config import)
- [ ] 6.3 Проверить создание серверной ИБ с загрузкой через remote ibcmd (`conf2ib.sh`, infobase create --load)
- [x] 6.4 Проверить загрузку расширения CFE в серверную ИБ через remote ibcmd (`ext2ib.sh`, config load)
- [x] 6.5 Проверить загрузку расширения XML в серверную ИБ через remote ibcmd (`ext2ib.sh`, config import)
- [x] 6.6 Проверить config apply через remote ibcmd (`V8_UPDATE_DB=1`)
- [x] 6.7 Проверить обратную совместимость: все операции без `V8_REMOTE_HOST` работают как раньше (локальный ibcmd)
- [x] 6.8 Проверить обработку ошибки scp (недоступный remote, неверный путь)
- [x] 6.9 Проверить обработку ошибки ssh (недоступный remote)
- [x] 6.10 Проверить корректность кодировки вывода ibcmd (chcp 65001)
- [x] 6.11 Проверить очистку remote temp после успешного и неуспешного выполнения
- [x] 6.12 Проверить очистку remote temp после ошибки scp
- [x] 6.13 Проверить несуществующий локальный путь в первом аргументе run_ibcmd
