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

После closure refresh — **9** project_id в `list_graph_projects` (Mirax вне scope).

| project_id | status | ingestion_state (2026-10-31 closure) |
|------------|--------|--------------------------------------|
| Dolea | ready | inherited |
| BuhDemoConf | ready | idle |
| BuhDemoExt | ready | idle |
| EnergyConf | ready | idle |
| EnergyExt | ready | idle |
| Rostviplast | ready | idle (conf: refresh отклонён `refresh_capability_unavailable`, координатор уже idle) |
| RostviplastExt | ready | idle |
| SmallBusinessConf | ready | idle |
| SmallBusinessExt | ready | idle |
| MiraxConf / MiraxExt | — | **SKIP** (нет ext XML; не в `list_graph_projects` после рестарта graph) |

Refresh: `temp/graph-orchestrate.py` + `scripts/mcp/refresh_graph_project.py`; пакетно — `scripts/mcp/refresh-graph-never-run.ps1`. Целевые `never_run` (кроме Mirax) завершены (`idle`).

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
| AI_Apps vpn-server | Канон **физически** `F:\AI_Apps\projects\vpn-server`; robocopy/MIR; старый `F:\AI_Cursor\vpn-server` — удалить или оставить заглушку `MOVED.md` (без symlink/junction) после закрытия worker |
| harness `temp/` | Очищен, оставлен `README.md` |

## 7. Git

| Репо | Ветка | SHA (до commit finish) | Push |
|------|-------|------------------------|------|
| AI_1C_harness | main | 589268a → **1.4.8 commit** | origin |
| AI_Apps_harness | main | e09928f | без изменений в проходе |

Onboarding: `docs/14_GitHub_и_upstream.md`, `docs/00_Подключить_проект.md`.

## 8. Ручные шаги (остаток)

1. **Mirax ext**: выгрузить расширение в `mirax_src\ext`, переиндекс + повторная регистрация `MiraxExt` в графе.
2. ~~Graph refresh never_run~~ — выполнено 2026-10-31 (см. §2).
3. **Upstream task**: после `gh auth login` убрать `-SkipGh` из `/TR` задачи планировщика.
4. **vpn-server**: удаление `F:\AI_Cursor\vpn-server` (или только `MOVED.md`) после закрытия Cursor worker; канон — Apps, без junction.
5. **projects.json**: сохранять **без BOM** (UTF-8 no BOM).

---

## 2026-10-31 closure

| # | Задача | Статус | Доказательство |
|---|--------|--------|----------------|
| 1 | Mirax ext XML → `mirax_src\ext` | **FAILED (нет источника)** | Поиск `Configuration.xml` / `*.cfe` с `mirax` и каталогов `*\mirax_src\ext`, `*\mirax\ext` в `F:\AI_Cursor`, `F:\AI_DeepSeek`, `F:\AI_Claude`, `F:\AI_1C` — **0** файлов ext. `F:\AI_1C\projects\mirax_src\ext` — только `.code-index` (0 XML). `mirax_src\conf` — **517** файлов. Registrar: `MiraxExt` → `metadata_source_unavailable` (лог `graph_registrar`). Reindex ext: **0** файлов, контейнер `mirax_code_index` Up, MCP `:8052` tools/list OK. |
| 2 | Graph refresh `never_run` | **DONE** | Оркестратор `temp/graph-orchestrate.py` (run2 2026-10-31). После рестарта `graph_mcp` — `list_graph_projects` total **9**, все целевые (кроме Mirax) с `ingestion_state=idle`; Dolea `inherited`. **MiraxConf / MiraxExt** — вне scope (нет ext XML, пользователь skip). См. таблицу ниже. `:8006/healthz` 200. |
| 3 | Перенос `vpn-server` → Apps | **PARTIAL** | Robocopy `/MIR` (догон `cursor-dns-watch/out/*`). Канон `F:\AI_Apps\projects\vpn-server`. Старый каталог занят: `node.exe` **PID 82696** (Cursor worker) — rename/delete отказ. `MOVED.md` в обоих путях: канон Apps, **без mklink/junction**. |
| 4 | `gh` в `AI_1C_upstream_daily` | **DONE** | `register-upstream-daily-task.ps1` без `-SkipGh`; TR → `run-upstream-daily.ps1`. Ручной прогон: отчёт `temp/upstream-check-20261030-2355.md`, gh API без `-SkipGh`. |
| 5 | Отчёт + store | **DONE** | Этот файл + копия в Project store `docs/harness-finish-report-2026-10-31.md`. |
| 6 | Git harness | **DONE** | Версия **1.4.9**, ветка `cursor/harness-closure-d682`, push origin. |

Версия харнеса: **1.4.9**. Дата closure: 2026-10-31.
