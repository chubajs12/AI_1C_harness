# Миграция данных проектов в `F:\AI_1C\projects` (2026-10-31)

Дополнение к переносу tasks (30.10.2026): обвязка, документы, скрипты контуров из legacy-путей.

**Источник по умолчанию:** `F:\AI_Claude\<project>\` (если есть).  
**Метод:** `robocopy /E /XO /R:1 /W:1`, без junction; исключены `indexes\`, `kit\`, `*_src`, дубликаты AGENTS/CLAUDE, секреты (`.env.local` → не копировались из legacy, кроме buh → `config\project.env.local`).

**Выбор путей:**

| Материал | Решение |
|----------|---------|
| ОЭК (energy) | Каталог `ОЭК\` в корне проекта — как у пользователя в Claude/Cursor |
| Инструкции (dolea) | Каталог `Инструкции\` в корне (не `docs\instructions`): пользовательские DOCX, отдельно от `docs\` процесса |
| Отчеты mirax | `docs\reports\` |

В legacy-каталогах скопированных деревьев — файл `MOVED.md` с каноническим путем.

## Таблица переносов

| Источник | Назначение | Файлов в назначении (после) | Добавлено approx | Пропуск / примечание |
|----------|------------|----------------------------:|-----------------:|----------------------|
| `F:\AI_Claude\energy\ОЭК` | `F:\AI_1C\projects\energy\ОЭК` | 2071 | 2071 | — |
| `F:\AI_Claude\mirax\docs\reports` | `F:\AI_1C\projects\mirax\docs\reports` | 5 | 0 | уже через `mirax/docs`; /XO |
| `F:\AI_Claude\dolea\Инструкции` | `F:\AI_1C\projects\dolea\Инструкции` | 600 | 600 | — |
| `F:\AI_DeepSeek\AI_1C\projects\buh_pryadchenko\scripts` | `F:\AI_1C\projects\buh_pryadchenko\scripts` | 10 | 10 | новый контур |
| legacy `scripts\1c\.env.local` | `F:\AI_1C\projects\buh_pryadchenko\config\project.env.local` | 1 | 1 | не в git |
| `F:\AI_Claude\dolea\docs` | `F:\AI_1C\projects\dolea\docs` | 2 | 0 | /XO |
| `F:\AI_Claude\dolea\openspec` | `F:\AI_1C\projects\dolea\openspec` | 5 | 5 | MOVED.md в источнике |
| `F:\AI_Claude\dolea\scripts` | `F:\AI_1C\projects\dolea\scripts` | 57 | 57 | |
| `F:\AI_Claude\dolea\tools` | `F:\AI_1C\projects\dolea\tools` | 468 | 468 | |
| `F:\AI_Claude\dolea\tasks` | `F:\AI_1C\projects\dolea\tasks` | 2407 | 0 | tasks уже были; /XO |
| `F:\AI_Claude\mirax\docs` | `F:\AI_1C\projects\mirax\docs` | 32 | 32 | включает reports |
| `F:\AI_Claude\mirax\openspec` | `F:\AI_1C\projects\mirax\openspec` | 5 | 5 | |
| `F:\AI_Claude\mirax\scripts` | `F:\AI_1C\projects\mirax\scripts` | 12 | 12 | |
| `F:\AI_Claude\mirax\.run` | `F:\AI_1C\projects\mirax\.run` | 2 | 2 | |
| `F:\AI_Claude\mirax\tasks` | `F:\AI_1C\projects\mirax\tasks` | 3 | 0 | /XO |
| `F:\AI_Claude\rostviplast\docs` | `F:\AI_1C\projects\rostviplast\docs` | 0 | 0 | пустой источник |
| `F:\AI_Claude\rostviplast\openspec` | `F:\AI_1C\projects\rostviplast\openspec` | 5 | 5 | |
| `F:\AI_Claude\rostviplast\scripts` | `F:\AI_1C\projects\rostviplast\scripts` | 13 | 13 | |
| `F:\AI_Claude\rostviplast\tasks` | `F:\AI_1C\projects\rostviplast\tasks` | 180 | 0 | /XO |
| `F:\AI_Claude\energy\docs` | `F:\AI_1C\projects\energy\docs` | 11 | 11 | |
| `F:\AI_Claude\energy\openspec` | `F:\AI_1C\projects\energy\openspec` | 5 | 5 | |
| `F:\AI_Claude\energy\scripts` | `F:\AI_1C\projects\energy\scripts` | 528 | 528 | |
| `F:\AI_Claude\energy\tools` | `F:\AI_1C\projects\energy\tools` | 6335 | 6335 | |
| `F:\AI_Claude\energy\.run` | `F:\AI_1C\projects\energy\.run` | 4 | 4 | |
| `F:\AI_Claude\energy\tasks` | `F:\AI_1C\projects\energy\tasks` | 6361 | 0 | /XO |
| `F:\AI_Claude\energy\VERSION` | `F:\AI_1C\projects\energy\VERSION` | 1 | 1 | файл |
| `F:\AI_Claude\energy\.v8-project.json` | `F:\AI_1C\projects\energy\.v8-project.json` | 1 | 1 | файл |

**Заглушки:** `MOVED.md` — `F:\AI_Claude\energy\ОЭК`, `F:\AI_Claude\dolea\Инструкции`, `F:\AI_Claude\mirax\docs\reports`, `F:\AI_Claude\buh_pryadchenko`, плюс `MOVED.md` в скопированных `docs/openspec/scripts/tools/.run` legacy-деревьях.

## Намеренно не копировалось

| Объект | Причина |
|--------|---------|
| `F:\AI_1C\projects\*_src` | Канон сырцов уже в AI_1C |
| `indexes\` в legacy | Индекс пересобирается в обвязке проекта |
| `kit\`, `AGENTS.md`, `CLAUDE.md` | Канон — `F:\AI_1C\harness` |
| `F:\AI_Cursor\dolea\scripts` | Подмножество; скопировано из AI_Claude |
| `buh_pryadchenko_src` | На диске не найден |

## PROJECT.md

Обновлены: `dolea`, `energy`, `mirax`, `rostviplast`; создан `F:\AI_1C\projects\buh_pryadchenko\PROJECT.md`.

## Проверка запроса пользователя

| Путь | Статус |
|------|--------|
| `F:\AI_Claude\energy\ОЭК` → `F:\AI_1C\projects\energy\ОЭК` | 2071 файл |
| `F:\AI_Claude\mirax\docs\reports` → `F:\AI_1C\projects\mirax\docs\reports` | 5 файлов |
| `F:\AI_Claude\dolea\Инструкции` → `F:\AI_1C\projects\dolea\Инструкции` | 600 файлов |
| `F:\AI_Claude\buh_pryadchenko` → `F:\AI_1C\projects\buh_pryadchenko` | контур + scripts; MOVED.md |

Скрипт прогона (временный): `F:\AI_1C\harness\temp\project-data-migrate-run.ps1`.

## Verification 2026-10-31

Повторная сверка legacy (`F:\AI_Claude\<p>\`, `F:\AI_DeepSeek\AI_1C\projects\<p>\`, `F:\AI_Cursor\<p>\` при наличии) с каноном `F:\AI_1C\projects\<p>\`. Исключены из сравнения: `tasks`, `*_src`, `indexes`, `kit`, `.git`, каталоги `.claude` (настройки агента, не данные контура). Файлы-секреты (`.env.local`, `.env` в legacy `scripts`) и заглушки `MOVED.md` в legacy не считаются GAP.

| path | legacy-only file count | canonical count | status |
|------|------------------------:|----------------:|--------|
| `energy\ОЭК` | 0 | 2071 | OK |
| `dolea\Инструкции` | 0 | 600 | OK |
| `mirax\docs\reports` | 0 | 32 | OK |
| `buh_pryadchenko` (wrapper: PROJECT.md, config, scripts, tasks, `.mcp.json`) | 0 | 14 | OK |
| `dolea\docs` | 0 | 2 | OK |
| `dolea\scripts` | 0 | 57 | OK |
| `dolea\tools` | 0 | 468 | OK |
| `mirax\docs` | 0 | 32 | OK |
| `mirax\scripts` | 0 | 12 | OK |
| `rostviplast\scripts` | 0 | 13 | OK |
| `rostviplast\docs` | 0 (legacy: только `MOVED.md`) | 0 | OK |
| `energy\scripts` | 0* | 528 | OK |
| `energy\tools` | 0 | 6335 | OK |

\* В `F:\AI_Claude\energy\scripts` остаются `MOVED.md` и устаревший `kit\build_agent_kit.py` (канон kit — харнес); в DeepSeek legacy — `.env` / `.env.local`, не переносятся.

**MOVED.md** на месте: `F:\AI_Claude\energy\ОЭК`, `F:\AI_Claude\dolea\Инструкции`, `F:\AI_Claude\mirax\docs\reports`, `F:\AI_Claude\buh_pryadchenko`.

**Robocopy:** не выполнялся (GAP по содержимому не выявлено).
