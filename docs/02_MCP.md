# MCP: что есть, для чего, как подключать

MCP-серверы — инструменты агента: поиск по коду и метаданным, справка, проверки, доступ к живой базе, управление
тестами. На машине они делятся на **общие** (один экземпляр на всех, не трогать) и **свой индексатор кода проекта**
(единственный контейнер, который заводится под проект). MCP 1С (HTTP-сервис расширения в базе) и Vanessa — тоже MCP,
но живут в 1С: первый — в публикации IIS базы проекта, второй — в сеансе TestManager.

Описания серверов дистрибутива (установка, параметры, лицензии) — `docs/mcp-servers/` (из `F:\AI_1C\upstream\mcp\docs`).

## 1. Сводная таблица

| Сервер | Адрес | Чей | Образ / источник | Для чего |
|--------|-------|-----|------------------|----------|
| индексатор кода | `http://localhost:<CODE_INDEX_PORT>/mcp` | **свой** | `bsl-indexer` 1.8.5 (Regsorm/code-index-mcp), `docker run` | код и метаданные conf/ext проекта |
| `graph-mcp` | `http://localhost:8006/mcp` (из скриптов `.../mcp/` со слэшем) | общий | `comol/1c_graph_metadata:light` + Neo4j + Ollama (эмбеддинги) | граф метаданных всех проектов, `project_id` |
| `1c-syntax-checker-mcp` | `http://localhost:8002/mcp` | общий | `comol/1c_syntaxcheck_mcp` (BSL Language Server) | синтаксис и стиль BSL |
| `1c-docs-mcp` | `http://localhost:8003/mcp` | общий | `comol/1c_help_mcp` (справка платформы 8.3.27) | синтаксис-помощник, методы, стандарты |
| `1c-templates-mcp` | `http://localhost:8004/mcp` | общий | `comol/template-search-mcp` | шаблоны кода + память (`remember`/`recall`) |
| `1c-ssl-mcp` | `http://localhost:8008/mcp` | общий | `comol/mcp_ssl_server` | API БСП: что уже есть в типовой |
| `1c-forms-mcp` | `http://localhost:8011/mcp` | общий | `desko77/1c-formsserver` | генерация и валидация `Form.xml` |
| `v8std` | `http://localhost:18766/mcp` | общий | `ghcr.io/zeegin/v8std-mcp:stable` | стандарты v8std.ru, диагностики BSL LS/ACC/EDT |
| MCP 1С | `http://127.0.0.1:<MCP1C_PORT>/<MCP1C_APP>/hs/mcp` (Basic) | своя публикация IIS (свой пул) | `tools/mcp1c/` (`MCP_Сервер` + `MCP_ВыполнениеКода`), `03_MCP_1С.md` | код и запросы в живой базе |
| Vanessa | `http://127.0.0.1:<VANESSA_MCP_PORT>/mcp` | свой процесс 1С | [Pr-Mex/vanessa-automation](https://github.com/Pr-Mex/vanessa-automation) single 1.2.043.28 + расширение `client_mcp` | управление тестированием UI |

Общие контейнеры работают постоянно (`restart: unless-stopped`), Docker Desktop: группа «1c» — syntax/docs/templates/
ssl/forms/v8std, группа «2graph» — граф. Их не пересоздавать, не останавливать, не удалять: ими пользуются все проекты.
Не отвечают — сообщить пользователю.

## 2. Когда что вызывать (обязательно, не по желанию)

| Ситуация | Инструмент |
|----------|-----------|
| найти объект, модуль, процедуру, текст | индексатор: `search_function`, `search_class`, `grep_code`, `grep_body`, `find_symbol`, `read_file`, `list_files` |
| структура объекта (реквизиты, ТЧ, формы, команды) | индексатор `get_object_structure`, `get_object_profile`; граф `get_object_dossier` |
| кто вызывает / что вызывает метод | индексатор `get_callers`, `get_callees`, `get_call_tree` |
| ссылки на объект, анализ влияния | индексатор `find_references`; граф `find_usages_of_object`, `find_object_referrers`, `trace_impact` |
| кто пишет в регистр | индексатор `get_register_writers`; граф `get_register_writers`, `find_register_movement_docs` |
| права ролей на объект | индексатор `get_role_rights`; граф `get_access_rights`; MCP 1С `execute_code` с `ПравоДоступа(…, <пользователь>)` (эффективные права пользователя) |
| обработчики формы, подписки на события | индексатор `get_form_handlers`, `get_event_subscriptions`; граф `get_form_structure` |
| схема СКД отчета | индексатор `get_dcs_schema`; граф `get_report_dcs_lineage` |
| правка любого `.bsl` | `1c-syntax-checker-mcp` `syntaxcheck` (файл — `scripts/mcp/syntaxcheck_file.py <файл>`) |
| метод платформы, синтаксис, ограничение | `1c-docs-mcp` `docsearch` / `docinfo` (не утверждать по памяти) |
| работа с файлами, длительные операции, пользователи, печать, строки | `1c-ssl-mcp` `ssl_search` — сначала искать в БСП |
| правка `Form.xml` | `1c-forms-mcp` `validate_form` (файл — `scripts/mcp/validate_form_file.py`) |
| стандарт, номер диагностики | `v8std` `v8std_search`, `v8std_explain_diagnostics`, `v8std_explain_snippet` |
| данные базы сейчас | MCP 1С `execute_query` / `execute_code` / `get_metadata_structure`; журнал регистрации — `tests/templates/event_log_errors.bsl` |
| интерфейс, тест | Vanessa (см. `04_Vanessa.md`) |

**Урок аудита Cursor (сентябрь 2026):** серверы были живы, но правила вызова были «по желанию» — за весь период
`v8std` вызван 0 раз, синтаксис проверялся в ~3% ходов с правкой BSL. Поэтому гейты в `AGENTS.md` — обязательные.

`v8std` — только локальный `:18766`. У него есть публичный `https://ai.v8std.ru/mcp` — код проекта туда не отправлять.

## 3. Свой индексатор кода (bsl-indexer)

Один контейнер на проект: `<PROJECT>_code_index`, обычный `docker run` без compose-группы, порт только на `127.0.0.1`,
исходники `conf`/`ext` смонтированы только на чтение, индексы — в `<PROJECT_ROOT>\indexes\code-index\{home,conf,ext}`
(внутри папки проекта: пользователь прямо просил не заводить соседние папки `<проект>_mcp`).

```powershell
scripts\mcp\code-index\start-code-index.ps1          # собрать образ (если нет) и создать/запустить контейнер
scripts\mcp\code-index\start-code-index.ps1 -Status  # состояние и /health
docker logs -f <PROJECT>_code_index                  # ход первичной индексации (ERP — часы, это норма)
scripts\mcp\code-index\reindex.ps1 -Repos ext,conf   # после выгрузки/загрузки/крупных правок
```

- Образ: `scripts/mcp/code-index/Dockerfile` (debian slim + бинарник `bsl-indexer` из GitHub Releases, версия
  `BSL_INDEXER_VERSION`), `entrypoint.sh` — демон-писатель индекса + `serve` по HTTP на 8030 внутри контейнера.
- `daemon.toml` генерирует скрипт: два репозитория `/repos/conf` и `/repos/ext` (алиасы `conf`/`ext` — параметр `repo`
  в инструментах).
- **Демон не получает событий изменения файлов с диска Windows** (bind mount) — индекс сам не обновляется; после
  выгрузки — `reindex.ps1` (по хешам, только измененные файлы). Признак устаревшего индекса — `grep_code` не находит
  текст, который точно есть в файле.
- Контейнер не стартует с `make mountpoint "/repos/ext/.code-index": read-only file system` — каталог выгрузки
  пересоздан и в нем нет пустой папки `.code-index` (точки монтирования): создать и `docker start`. Скрипт создает ее
  сам; помнить при замене `ext` целиком (прием CFE боевой).
- Инструменты (33): `search_function`, `search_class`, `search_text`, `search_terms`, `grep_code`, `grep_body`,
  `grep_text`, `find_symbol`, `find_references`, `find_path`, `find_path_bsl`, `find_data_path`, `get_function`,
  `get_class`, `get_file_summary`, `get_imports`, `get_callers`, `get_callees`, `get_call_tree`, `get_object_structure`,
  `get_object_profile`, `get_form_handlers`, `get_event_subscriptions`, `get_register_writers`, `get_role_rights`,
  `get_data_links`, `get_dcs_schema`, `bsl_sql`, `read_file`, `list_files`, `stat_file`, `get_stats`, `health`.

## 4. Граф метаданных (общий, `project_id` обязателен)

Один `graph_mcp` на все проекты машины (Neo4j + эмбеддинги процедур на GPU через Ollama). Конфигурация и расширение —
два разных проекта графа: `<Project>Conf` и `<Project>Ext`. Во **все** вызовы передавать `project_id`.

Подключение нового проекта — **изменение общей инфраструктуры, только с согласия пользователя**:

1. В `F:\AI_1C\upstream\mcp\graph\docker-compose.yml` (сервис `mcp`, `volumes`) добавить монтирование выгрузок только на чтение:
   `- "F:/AI_1C/projects/<проект>_src/conf:/app/<проект>_conf:ro"` и `.../ext:/app/<проект>_ext:ro`.
2. Пересоздать только сервис графа: `docker compose -f F:\AI_1C\upstream\mcp\graph\docker-compose.yml --env-file
   F:\AI_1C\upstream\mcp\graph\.env up -d mcp` (секреты лицензии — в `.env`, не публиковать). Граф недоступен ~3 минуты для всех.
3. В `F:\AI_1C\upstream\mcp\graph\registrar\projects.json` добавить
   `{ "project_id": "<Project>Conf", "configuration_root": "/app/<проект>_conf" }` и то же для Ext — сервис
   `graph_registrar` раз в минуту дорегистрирует проекты (реестр живет в памяти `graph_mcp` и теряется при рестарте).
4. Построить индекс: `refresh_graph_project` с `project_id` и уникальным `operation_id` (например, uuid4). У сервера
   **одна очередь на всю инсталляцию**: занят другим проектом — `ingestion_busy`, повторить позже.
5. Готовность — `list_graph_projects` (`status: ready`), ход — `get_indexing_status`.

```powershell
python scripts\mcp\mcp_http.py http://127.0.0.1:8006/mcp/ list_graph_projects '{}'
# PowerShell снимает кавычки из JSON — используйте обертку:
python scripts\mcp\refresh_graph_project.py MyprojExt
# Пакетно для ingestion_state=never_run (ожидание ingestion_busy):
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\mcp\refresh-graph-never-run.ps1
```

После правки метаданных — `refresh_graph_project` (инкрементально) нужного `project_id`. Отчеты Конфигуратора `.txt`
не нужны: сервер сам синтезирует отчет из Designer XML. Полная перестройка большой конфигурации — часы (в Energy
5 часов на ERP с индексатором вместе, на старом контуре было 2–3 дня) — это норма, не зависание.

Полезные инструменты: `get_object_dossier`, `search_metadata` (JSON-операции, без LLM), `find_usages_of_object`,
`trace_impact`, `get_register_writers`, `get_form_structure`, `get_access_rights`, `compare_base_and_extension`,
`run_graph_cypher_template`, `get_graph_tool_schema` (точная схема инструмента).

## 5. Подключение MCP к агенту

Примеры конфигураций для разных клиентов — `mcp/` в корне комплекта (Claude Code `.mcp.json`, Cursor, OpenCode,
Codex). Все серверы — обычный `http://localhost:<порт>/mcp` (streamable HTTP), TLS-прокси не нужен (в Energy его
поднимали из-за ложного впечатления, что приложение требует `https`; оказалось не нужно, прокси удален).

- Коннекторы сессии поднимаются один раз при старте сессии: после изменения набора MCP — переподключить в клиенте или
  начать новую сессию.
- Сервер жив, а коннектор не поднялся — работать через `python scripts\mcp\mcp_http.py <порт> <инструмент> '<json>'`
  (это не обход правила «MCP-first»: это тот же MCP).
- MCP 1С и Vanessa из скриптов вызываются только по HTTP (`mcp1c.py`, `va_mcp.py`) — без окон согласия клиента.

## 6. Если MCP «мертв»

1. `scripts\doctor.ps1` — что именно не отвечает.
2. Общий сервер не отвечает — сообщить пользователю, работу с метаданными остановить; контейнеры не пересоздавать.
3. Свой индексатор — `start-code-index.ps1` (`docker start`), смотреть `docker logs`.
4. MCP 1С — `mcp1c.py --status`: 503 — пул остановлен (`mcp-pool.ps1 -Start`; идет UpdateDB — дождаться), 401 — пароль
   `USER`, 404 — нет публикации (`publish-mcp.ps1`), инструментов нет — расширения (`install-mcp.ps1`); Vanessa —
   `restart-vanessa.ps1`.
