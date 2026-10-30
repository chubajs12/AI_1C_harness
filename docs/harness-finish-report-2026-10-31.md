# Harness finish report — 2026-10-31

Линия **AI_1C**, машина агента. Автономный finish pass.

## 1. Docker compose groups

| Compose project | Config | Running |
|-----------------|--------|---------|
| **1c** | `F:\MCP_Distr\compose-1c\docker-compose.yml` | 6 |
| **2graph** | `F:\MCP_Distr\graph\docker-compose.yml` | 4 |
| **3codeindex** | `F:\MCP_Distr\compose-codeindex\docker-compose.yml` | 6 |

Контейнеры: `syntaxcheck_mcp-1c`, `help_mcp-1c`, `templates_mcp-1c`, `ssl_mcp-1c`, `forms_mcp-1c`, `v8std_mcp-1c`, `graph_mcp`, `graph_neo4j`, `graph_ollama`, `graph_registrar`, `dolea_code_index`, `rostviplast_code_index`, `mirax_code_index`, `energy_code_index`, `buh_demo_code_index`, `smallbusiness_code_index`.

- Контейнеров/образов с `_bak_` в имени: **нет** (проверка `docker ps -a`, `docker images`).
- Исправлено вне харнеса: `F:\MCP_Distr\graph\registrar\projects.json` — убран UTF-8 BOM (registrar падал с `JSONDecodeError`, проекты не регистрировались). После fix — перезапуск `graph_registrar`, регистрация Energy/Rostviplast/BuhDemo/SmallBusiness.

## 2. Индексаторы и граф (dolea, mirax, rostviplast, energy)

| Проект | Порт | Сырцы | ext reindex 31.10 | Индекс MCP |
|--------|------|-------|-------------------|------------|
| dolea | 8013 | `dolea_src` | 1193 без изменений | tools/list OK |
| rostviplast | 8042 | `rostviplast_src` | 83 без изменений | OK |
| energy | 8041 | `energy_ext_src` | 2399 без изменений | OK |
| mirax | 8052 | `mirax_src` | **0 файлов** в ext | OK, ext пуст/не выгружен |

Дополнительно в **3codeindex**: buh_demo (8062), smallbusiness (8061) — running.

### Graph (`http://127.0.0.1:8006/mcp/`, health 200)

После fix registrar — **10** project_id в `list_graph_projects` (Dolea + EnergyConf/Ext + Rostviplast/Ext + demos + MiraxConf).

| project_id | status | ingestion_state |
|------------|--------|-----------------|
| Dolea | ready | inherited (данные есть) |
| EnergyConf, EnergyExt | ready | never_run |
| Rostviplast, RostviplastExt | ready | never_run |
| MiraxConf | registered | never_run |
| **MiraxExt** | — | **не зарегистрирован** — `metadata_source_unavailable` (нет читаемого XML в `/app/mirax_ext`) |
| BuhDemo*, SmallBusiness* | ready | never_run |

`refresh_graph_project` (incremental): Dolea — `ingestion_busy`; остальные до fix — `project_not_registered`. После fix — зарегистрированы; **полный refresh графа для never_run — длительная операция**, не запускалась до конца в этом проходе (ручной шаг ниже).

## 3. scripts/new-project.ps1

- Путь: `F:\AI_1C\harness\scripts\new-project.ps1`
- Параметры: `-Name`, `-SrcRoot` (опционально), `-WhatIf`, `-Force`
- Dry-run: `fakeproj999` — OK (см. `docs/00_Подключить_проект.md`)

## 4. ПДн

- `rules/pdn-anonymization.md`
- `docs/15_ПДн_обезличивание.md`

## 5. Daily upstream

- Скрипт: `scripts/check-upstream-releases.ps1` (+ MCP local folder + digest образов compose)
- Task Scheduler: **`AI_1C_upstream_daily`**, ежедневно **07:00**, `-SkipGh` (пока нет `gh auth` в задаче)
- Док: `docs/11_Upstream_релизы.md`

## 6. Миграции / cleanup

| Проверка | Результат |
|----------|-----------|
| energy | `F:\AI_1C\projects\energy`, сырцы `energy_ext_src`, ext есть, tasks ~34 каталогов |
| AI_Apps vpn-server | Канон `F:\AI_Apps\projects\vpn-server`; `F:\AI_Cursor\vpn-server` **ещё занят** (не junction) — удаление/junction после закрытия сессии |
| harness `temp/` | Очищен, оставлен `README.md` |

## 7. Git

| Репо | Ветка | SHA (до commit finish) | Push |
|------|-------|------------------------|------|
| AI_1C_harness | main | 589268a → **1.4.8 commit** | origin |
| AI_Apps_harness | main | e09928f | без изменений в проходе |

Onboarding: `docs/14_GitHub_и_upstream.md`, `docs/00_Подключить_проект.md`.

## 8. Ручные шаги (остаток)

1. **Mirax ext**: выгрузить расширение в `mirax_src\ext`, переиндекс + повторная регистрация `MiraxExt` в графе.
2. **Graph refresh**: для `EnergyConf`, `EnergyExt`, `Rostviplast*`, `MiraxConf` — `refresh_graph_project` с новым `operation_id` (часы на больших conf); дождаться окончания `ingestion_busy` на Dolea перед refresh Dolea.
3. **Upstream task**: после `gh auth login` убрать `-SkipGh` из `/TR` задачи планировщика.
4. **vpn-server**: junction/удаление `F:\AI_Cursor\vpn-server` по согласию пользователя.
5. **projects.json**: сохранять **без BOM** (UTF-8 no BOM).

---

## 2026-10-31 closure

| # | Задача | Статус | Доказательство |
|---|--------|--------|----------------|
| 1 | Mirax ext XML → `mirax_src\ext` | **FAILED (нет источника)** | Поиск `Configuration.xml` / `*.cfe` с `mirax` и каталогов `*\mirax_src\ext`, `*\mirax\ext` в `F:\AI_Cursor`, `F:\AI_DeepSeek`, `F:\AI_Claude`, `F:\AI_1C` — **0** файлов ext. `F:\AI_1C\projects\mirax_src\ext` — только `.code-index` (0 XML). `mirax_src\conf` — **517** файлов. Registrar: `MiraxExt` → `metadata_source_unavailable` (лог `graph_registrar`). Reindex ext: **0** файлов, контейнер `mirax_code_index` Up, MCP `:8052` tools/list OK. |
| 2 | Graph refresh `never_run` | **IN PROGRESS** | `list_graph_projects`: 9× `never_run` (+ Dolea `inherited`). Старт `temp/graph-refresh-queue.py` (ожидание `ingestion_busy`). `get_indexing_status`: `bsl_code_graph` + `xml_data_sources` **running** (Dolea `/app/code`), `any_running=true`. После idle — очередь вызывает `refresh_graph_project.py` для BuhDemo*, Energy*, MiraxConf, Rostviplast*, SmallBusiness*. Скрипты: `scripts/mcp/refresh_graph_project.py`, `scripts/mcp/refresh-graph-never-run.ps1`. `graph_mcp` healthy, `:8006/healthz` 200. |
| 3 | Junction `F:\AI_Cursor\vpn-server` | **PARTIAL** | Lock: `node.exe` (Cursor worker). Rename каталога — отказ. Robocopy → `F:\AI_Apps\projects\vpn-server` (файлов **306** vs **305** в старом). `F:\AI_Cursor\vpn-server\MOVED.md` с командой `mklink /J`. Junction не создан (каталог занят). |
| 4 | `gh` в `AI_1C_upstream_daily` | **DONE** | `register-upstream-daily-task.ps1` без `-SkipGh`; TR → `run-upstream-daily.ps1`. Ручной прогон: отчёт `temp/upstream-check-20261030-2355.md`, gh API без `-SkipGh`. |
| 5 | Отчёт + store | **DONE** | Этот файл + копия в Project store `docs/harness-finish-report-2026-10-31.md`. |
| 6 | Git harness | **DONE** | Версия **1.4.9**, ветка `cursor/harness-closure-d682`, push origin. |

Версия харнеса: **1.4.9**. Дата closure: 2026-10-31.
