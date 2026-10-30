# Инструменты OneBridge (справочник)

Снято с живого OneBridge (07.10.2026) запросом `tools/list`. Вызов из скриптов — `scripts/onebridge/ob_client.py --tool <инструмент> '<json>'`, BSL — `ob_client.py <файл.bsl>`. Как этим пользоваться — `09_OneBridge_запасной_вариант.md`. Основной канал — MCP 1С (`03a_MCP_1С_инструменты.md`).

| Инструмент | Параметры |
|------------|-----------|
| `execute_query` | `query`, `params`, `limit`, `include_schema` |
| `execute_code` | `code` |
| `get_metadata` | `filter`, `meta_type`, `name_mask`, `limit`, `offset`, `sections`, `extension_name` |
| `get_event_log` | `start_date`, `end_date`, `limit`, `levels`, `events`, `object_description`, `link`, `data`, `metadata_type`, `user`, `session`, `application`, `computer`, `comment_contains`, `transaction_status`, `same_second_offset` |
| `get_object_by_link` | `link` |
| `get_link_of_object` | `object_description` |
| `find_references_to_object` | `target_object_description`, `search_scope`, `meta_filter`, `limit_hits`, `limit_per_meta`, `timeout_budget_sec` |
| `get_access_rights` | `metadata_object`, `user_name`, `rights_filter`, `roles_filter` |

## `execute_query`

Execute a query in 1C query language and return the results.

This tool executes queries on the 1C:Enterprise database using the 1C query language.
Results are returned as JSON or TOON format.

Параметры:

- `query` (string, обязательный) — The query text in 1C query language (e.g., "ВЫБРАТЬ * ИЗ Справочник.Номенклатура")
- `params` (object) — Optional dictionary of query parameters (e.g., {"Param1": "value1"}). Object references use format {"_objectRef": true, "УникальныйИдентификатор": "uuid", "ТипОбъекта": "СправочникСсылка.X"}
- `limit` (integer) — Maximum number of rows to return (default: 100, max: 1000)
- `include_schema` (boolean) — Include column type schema in response (default: False)

## `execute_code`

Execute arbitrary code in 1C language.

This tool executes code on the 1C:Enterprise server using the Execute() operator.
The result is returned from the 'Результат' (Result) variable as JSON or TOON format.

Important limitations (code is executed as a statement block, not a full module):
- Do NOT declare procedures/functions (`Процедура/Функция`) inside the snippet.
- Do NOT use `Возврат` (Return). Instead assign a value to `Результат`.

WARNING: Some dangerous operations are blocked for safety reasons.

Параметры:

- `code` (string, обязательный) — The 1C code to execute. Use 'Результат = ...' to return a value.

## `get_metadata`

Get metadata information about 1C database objects.

This tool returns information about the structure of the 1C database in JSON format.

Usage modes:
1. Summary (root types): No parameters (filter/meta_type/name_mask not provided)
   Returns:
     - data: list of root metadata types with counts (Тип, Количество)
     - configuration: configuration/platform info (when available) as a top-level field

2. Filtered list: Use 'meta_type' and/or 'name_mask' parameters
   Example: meta_type="Документ", name_mask="реализ"
   Returns: List of objects matching the criteria.
   Each item includes: ПолноеИмя, Синоним.
   List results are sorted by ПолноеИмя and support pagination via offset.
   List mode response always includes pagination metadata:
     - truncated, limit, returned, count, offset, has_more, next_offset
   Fields truncated/has_more indicate whether more results exist.

3. Detailed structure: Use 'filter' parameter with exact full name
   Example: filter="Справочник.Номенклатура"
   Returns: Full structure with attributes, dimensions, resources, tabular sections

3a. Specific collection element: Use 'filter' with full path to element
   Collection names are in singular (platform ПолноеИмя() format):
     filter="Справочник.Контрагенты.Реквизит.ИНН"
     filter="РегистрНакопления.Остатки.Измерение.Номенклатура"
     filter="РегистрНакопления.Остатки.Ресурс.Количество"
     filter="Задача.Задача.РеквизитАдресации.Исполнитель"
     filter="Справочник.Контрагенты.СтандартныйРеквизит.Наименование"
     filter="Документ.Реализация.ТабличнаяЧасть.Товары"
     filter="Документ.Реализация.ТабличнаяЧасть.Товары.Реквизит.Номенклатура"
   Use with sections=["properties"] to get extended element properties
   (ПроверкаЗаполнения, ЗначениеЗаполнения, Ведущее, Использование, etc.)

4. Extensions support: Use 'extension_name' parameter
   - extension_name not provided: work with main configuration (default)
   - extension_name="": get list of all connected extensions
   - extension_name="ExtensionName": work with objects inside the specified extension

Параметры:

- `filter` (string) — Full name of object (e.g., "Справочник.Номенклатура") or full path to collection element (e.g., "Справочник.Контрагенты.Реквизит.ИНН", "РегистрНакопления.Остатки.Измерение.Номенклатура")
- `meta_type` (string/array) — Object type filter for list (string or list). Use "*" to list across all root types.
- `name_mask` (string) — Search mask for name/synonym (case-insensitive substring search)
- `limit` (integer) — Maximum number of objects in list (default: 100, max: 1000)
- `offset` (integer) — Offset for pagination in list mode (default: 0)
- `sections` (array) — Detail sections to include (works only with filter). Supported: properties, forms, commands, layouts, predefined, movements, characteristics (movements is only available for Документ objects)
- `extension_name` (string) — Extension name (None=main config, ""=list extensions, "Name"=extension objects). Whitespace-only values are rejected.

## `get_event_log`

Get event log entries from 1C database with filtering options and cursor pagination.

This tool retrieves entries from the 1C event log (Журнал регистрации)
with optional filtering by date range, importance level, event type,
and additional filters for data object, metadata type, user, session, etc.
Results are returned as JSON or TOON format.

Supports cursor pagination for iterating through large result sets:
- Response includes last_date, next_same_second_offset, and has_more
- For next page: use last_date as start_date and next_same_second_offset as same_second_offset

Параметры:

- `start_date` (string) — Start date in ISO 8601 format (YYYY-MM-DDTHH:MM:SS). For pagination: use last_date from previous response.
- `end_date` (string) — End date in ISO 8601 format (YYYY-MM-DDTHH:MM:SS). If not provided, no end date filter is applied.
- `limit` (integer) — Maximum number of records to return (default: 100, max: 1000).
- `levels` (array) — List of importance levels to filter by. Valid values: "Information", "Warning", "Error", "Note". If not provided, all levels are returned.
- `events` (array) — List of event types to filter by (e.g., "_$Data$_.New", "_$Session$_.Start"). If not provided, all event types are returned.
- `object_description` (object) — Object description from execute_query results. Priority: object_description > link > data. Example: {"_objectRef": true, "УникальныйИдентификатор": "...", "ТипОбъекта": "..."}
- `link` (string) — Navigation link in format e1cib/data/Type.Name?ref=HexGUID. Priority: object_description > link > data.
- `data` (string) — Reference to data object (navigation link) - for backward compatibility. Priority: object_description > link > data.
- `metadata_type` (array) — List of metadata object types to filter by. Example: ["Документ.РеализацияТоваровУслуг", "Справочник.Номенклатура"].
- `user` (array) — List of user names to filter by.
- `session` (array) — List of session numbers to filter by.
- `application` (array) — List of application types to filter by. Valid values: "ThinClient", "WebClient", "ThickClient", "BackgroundJob", "Designer", "COMConnection", "Server", "WebService", "HTTPService", "ODataInterface", "MobileAppClient", "MobileAppServer", "1CV8C", "1CV8", etc.
- `computer` (string) — Computer name to filter by.
- `comment_contains` (string) — Substring to search in comment (case-insensitive).
- `transaction_status` (string) — Transaction status to filter by. Valid values: "Committed", "RolledBack", "NotApplicable", "Unfinished".
- `same_second_offset` (integer) — Skip N records with the same second as start_date (for pagination). Use next_same_second_offset from previous response. Requires start_date.

## `get_object_by_link`

Get 1C object data by navigation link.

This tool retrieves complete object data from the 1C:Enterprise database
using a navigation link. The link format is e1cib/data/Type.Name?ref=HexGUID.
Results are returned as JSON or TOON format.

Параметры:

- `link` (string, обязательный) — Navigation link in format e1cib/data/Type.Name?ref=HexGUID (e.g., "e1cib/data/Справочник.Контрагенты?ref=80c6cc1a7e58902811ebcda8cb07c0f5")

## `get_link_of_object`

Generate a 1C navigation link from an object description.

This tool converts an object description (returned by execute_query) into a clickable
navigation link that can be used to open the object directly in 1C.

Use this tool to provide users with clickable links to 1C objects after finding them
with execute_query.

Параметры:

- `object_description` (object, обязательный) — Object description from execute_query results with fields: _objectRef (must be true), УникальныйИдентификатор (UUID), ТипОбъекта (e.g., "СправочникСсылка.Контрагенты"), Представление (optional)

## `find_references_to_object`

Find references to a given object across specified metadata collections.

This tool searches for references to the target object in documents, catalogs,
and registers. It checks all fields whose type can contain a reference to the
target object type, then queries for actual matches.

The search is performed in two stages:
1. Candidate discovery: metadata traversal to find fields that can hold the target type
2. Query execution: actual queries to find objects/records referencing the target

Параметры:

- `target_object_description` (object, обязательный) — Object description from execute_query results with fields: _objectRef (must be true), УникальныйИдентификатор (UUID), ТипОбъекта (e.g., "СправочникСсылка.Контрагенты"), Представление (optional)
- `search_scope` (array, обязательный) — List of search scopes to check. Valid values: "documents", "catalogs", "information_registers", "accumulation_registers", "accounting_registers", "calculation_registers".
- `meta_filter` (object) — Optional metadata filter dict with fields: names (list of exact metadata object names) and name_mask (case-insensitive search mask). If names is provided, name_mask is ignored.
- `limit_hits` (integer) — Maximum total number of hits (default: 200, max: 10000).
- `limit_per_meta` (integer) — Maximum hits per metadata object (default: 20, max: 1000).
- `timeout_budget_sec` (integer) — Time budget in seconds for the search (default: 30, min: 5, max: 300).

## `get_access_rights`

Get role permissions for a metadata object and optionally effective rights for a user.

This tool retrieves information about what rights each role grants for the specified
metadata object. If a user name is provided, it also calculates the effective rights
for that user (sum of all their roles).

IMPORTANT limitations:
- effective_rights is "rights by sum of roles", NOT a guarantee of real access
- RLS (Row Level Security) is NOT taken into account
- Contextual restrictions (by organizations, departments) are NOT taken into account
- This is a check of "what is allowed by roles", not "what the user will actually see"

Runtime requirements:
- Admin rights are required: AccessRight() with 3rd parameter (Role/User) requires admin rights
- Privileged mode is forbidden: if enabled, AccessRight() always returns True, result is meaningless

Параметры:

- `metadata_object` (string, обязательный) — Full metadata object name (e.g., "Справочник.Контрагенты", "Документ.РеализацияТоваровУслуг")
- `user_name` (string) — Optional user name for effective rights calculation (case-insensitive search)
- `rights_filter` (array) — Optional list of rights to show in result (default: all applicable rights for type)
- `roles_filter` (array) — Optional list of roles to show (default: all roles with rights)

