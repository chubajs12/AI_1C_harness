# MCP_ВыполнениеKoda: разработка и deploy

Компонент линии 1С — расширение с инструментами `execute_code` и `execute_query` к коробке [MCP_Сервер](https://github.com/vladimir-kharin/1c_mcp). Исходный код: [github.com/chubajs12/MCP_VypolnenieKoda](https://github.com/chubajs12/MCP_VypolnenieKoda).

## Пути на диске (chubajs12)

| Роль | Путь |
|------|------|
| Канонический git clone (`main`) | `F:\AI_1C\upstream\git\MCP_VypolnenieKoda` |
| Dev worktree (`develop`, Cursor) | `F:\AI_1C\projects\mcp-vypolnenie-koda_dev` |
| Обвязка проекта | `F:\AI_1C\projects\mcp-vypolnenie-koda\` (`PROJECT.md`, `docs/branching.md`) |
| Дистрибутив для баз | `F:\AI_1C\harness\tools\mcp1c\MCP_ВыполнениеКода_v*.cfe` |
| Установка в базу | `scripts\mcp1c\install-mcp.ps1` (с согласия пользователя) |

Корень `F:\AI_1C\` не содержит отдельной папки репозитория (перенос 2026-10-31 → `upstream\git\`). Без junction.

## Поток разработки

1. Открыть в Cursor `F:\AI_1C\projects\mcp-vypolnenie-koda\MCP_VypolnenieKoda.dev.code-workspace` (ветка `develop` в корне `mcp-vypolnenie-koda_dev`).
2. Правки в `src/`, сборка CFE в `build/` (Конфигуратор Full → UpdateDB → DumpCfg; `build/` не в git).
3. Commit + push `origin develop`.
4. Merge `develop` → `main` на GitHub (review).
5. Deploy в линию:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\AI_1C\harness\scripts\mcp\sync-mcp-vypolnenie-koda.ps1
```

Скрипт идempotent: `git fetch` + `pull --ff-only` canonical `main`; если SHA изменился — копирует последний `MCP_ВыполнениеКода_v*.cfe` в `tools\mcp1c\`, старый — в `tools\mcp1c\old\`. Лог — `harness\temp\sync-mcp-vypolnenie-koda-*.log`, state — `temp\mcp-vypolnenie-koda-deploy.sha`.

6. Обновить расширение в нужных базах: `install-mcp.ps1` с `KIT_ENV_FILE` проекта (изменение базы — только с согласия). После обновления — `mcp-pool.ps1 -Stop` / `-Start` или recycle пула (см. `docs/03_MCP_1С.md`).

Docker-контейнеры **не** перезапускаются: компонент живет в IIS/1С. Общие MCP Docker — `F:\AI_1C\upstream\mcp\` (`docs/12_Docker_общие_MCP.md`).

## Upstream watch

Репозиторий в `scripts/upstream-watchlist.json` (`id`: `MCP_VypolnenieKoda`, GitHub `chubajs12/MCP_VypolnenieKoda`). Ежедневный dry-run: `scripts/check-upstream-releases.ps1` (вместе с остальными upstream). После уведомления о новом release/tag на `main` — `sync-mcp-vypolnenie-koda.ps1`, затем решение по `install-mcp.ps1` по проектам.

Коробка `1c_mcp` — отдельный upstream в `upstream/git/1c_mcp` → `tools/mcp1c` (см. `docs/14_GitHub_и_upstream.md`).

## Worktree (один раз)

```powershell
git -C F:\AI_1C\upstream\git\MCP_VypolnenieKoda worktree add F:\AI_1C\projects\mcp-vypolnenie-koda_dev develop
```
