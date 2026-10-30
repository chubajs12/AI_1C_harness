# Инструменты MCP 1С (справочник)

Снято с живого сервера (MCP_Сервер 1.9.1 + MCP_ВыполнениеКода 1.0.1, 16.10.2026) запросом `tools/list`. Вызов из скриптов — `python scripts/mcp1c/mcp1c.py --tool <инструмент> '<json>'`, BSL — `mcp1c.py <файл.bsl>`, запрос — `mcp1c.py --query "…"`. Как этим пользоваться — `03_MCP_1С.md`. У другой версии коробки набор может отличаться: актуальный — `mcp1c.py --list`.

| Инструмент | Расширение | Параметры |
|------------|------------|-----------|
| `list_metadata_objects` | MCP_Сервер | `metaType`, `nameMask`, `maxItems` |
| `get_metadata_structure` | MCP_Сервер | `metaType`, `name`, `sections`, `maxTypesInComposite` |
| `execute_query` | MCP_ВыполнениеКода | `query`, `params`, `limit`, `include_schema` |
| `execute_code` | MCP_ВыполнениеКода | `code` |

Чего нет по сравнению с OneBridge (`09a`): `get_event_log`, `get_object_by_link`, `get_link_of_object`, `find_references_to_object`, `get_access_rights` — то же делается через `execute_code`: журнал регистрации — `tests/templates/event_log_errors.bsl` (`ВыгрузитьЖурналРегистрации`), права — `ПравоДоступа("Чтение", Метаданные.<Вид>.<Имя>, ПользователиИнформационнойБазы.НайтиПоИмени("<имя>"))` без привилегированного режима, навигационная ссылка объекта — `ПолучитьНавигационнуюСсылку(Ссылка)`; объект ищется запросом по реквизитам или по `УникальныйИдентификатор` из ответа `execute_query` (`ПолучитьСсылку(Новый УникальныйИдентификатор("<uuid>"))`).

## `list_metadata_objects`

Получение списка объектов метаданных конфигурации с возможностью фильтрации по типу и имени

Параметры:

- `metaType` (string, обязательный) — Тип объекта метаданных. Значения: `Catalogs`, `Documents`, `InformationRegisters`, `AccumulationRegisters`, `AccountingRegisters`, `CalculationRegisters`, `ChartsOfCharacteristicTypes`, `ChartsOfAccounts`, `ChartsOfCalculationTypes`, `BusinessProcesses`, `Tasks`, `ExchangePlans`, `FilterCriteria`, `Reports`, `DataProcessors`, `Enums`, `CommonModules`, `SessionParameters`, `CommonTemplates`, `CommonPictures`, `XDTOPackages`, `WebServices`, `HTTPServices`, `WSReferences`, `Styles`, `Languages`, `FunctionalOptions`, `FunctionalOptionsParameters`, `DefinedTypes`, `CommonAttributes`, `CommonCommands`, `CommandGroups`, `Constants`, `CommonForms`, `Roles`, `Subsystems`, `EventSubscriptions`, `ScheduledJobs`, `SettingsStorages`, `Sequences`, `DocumentJournals`, `ExternalDataSources`, `Interfaces`.
- `nameMask` (string) — Маска имени объекта. Проверяется на вхождение подстроки в имя или синоним объекта.
- `maxItems` (number) — Максимальное количество возвращаемых результатов. По умолчанию `100`.

## `get_metadata_structure`

Структура объекта метаданных: поля, ТЧ, владельцы, предопределенные, значения перечисления. Для документов — список регистров движений. Опционально (секция subsystems) — список подсистем объекта.

Параметры:

- `metaType` (string, обязательный) — Тип объекта метаданных. Значения: `Catalogs`, `Documents`, `InformationRegisters`, `AccumulationRegisters`, `AccountingRegisters`, `CalculationRegisters`, `Reports`, `DataProcessors`, `ChartsOfCharacteristicTypes`, `ChartsOfAccounts`, `ChartsOfCalculationTypes`, `BusinessProcesses`, `Tasks`, `ExchangePlans`, `Enums`.
- `name` (string, обязательный) — Точное имя объекта метаданных (без учета регистра)
- `sections` (array) — Секции вывода. fields=поля (стандартные+реквизиты+измерения+ресурсы), tabular_sections=ТЧ, predefined=предопределенные, owners=владельцы, register_records=регистры движений (только для документов), subsystems=подсистемы прямого вхождения. По умолчанию все, кроме predefined и subsystems. Для Enums применяется только subsystems. Значения: `fields`, `tabular_sections`, `predefined`, `owners`, `register_records`, `subsystems`.
- `maxTypesInComposite` (number) — Лимит типов составного реквизита (0 - без лимита). По умолчанию `10`.

## `execute_query`

Выполняет запрос на языке запросов 1С на сервере под текущим пользователем (с его правами и ограничениями доступа). Ответ - JSON: success, data (массив строк-объектов), count (строк в результате), returned, truncated, schema. Ссылки в data - объекты {_objectRef, УникальныйИдентификатор, ТипОбъекта, Представление}, пустые ссылки - null.

Параметры:

- `query` (string, обязательный) — Текст запроса на языке запросов 1С. Пакетный запрос возвращает результат последнего запроса пакета.
- `params` (object) — Параметры запроса: {"ИмяПараметра": значение}. Значение - строка, число, булево, null, массив (для В (&Список)), дата строкой "ГГГГ-ММ-ДДTЧЧ:ММ:СС", ссылка {"_objectRef": true, "ТипОбъекта": "СправочникСсылка.Контрагенты", "УникальныйИдентификатор": "<uuid>"} (как в ответе инструмента; у перечисления - имя значения) или предопределенное значение {"_predefined": "Перечисление.ХозяйственныеОперации.РеализацияКлиенту"}.
- `limit` (number) — Сколько строк вернуть (0 - все строки). По умолчанию `100`.
- `include_schema` (boolean) — Добавить в ответ типы колонок (schema)

## `execute_code`

Выполняет код на встроенном языке 1С на сервере (оператор Выполнить) под текущим пользователем и возвращает значение переменной Результат. Код - последовательность операторов: без Процедура/Функция и без Возврат. Ответ - JSON: success, data (значение Результат: примитивы, массивы, структуры, соответствия, таблицы и деревья значений, ссылки {_objectRef, ...}, ДвоичныеДанные - строкой Base64), messages (тексты Сообщить, если были). Пользователь с правом Администрирование выполняет код без безопасного режима, остальные - в безопасном режиме.

Параметры:

- `code` (string, обязательный) — Код на встроенном языке 1С. Значение для ответа присвоить переменной Результат.
