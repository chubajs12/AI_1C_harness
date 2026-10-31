# Миграция upstream + MCP (chubajs12, 2026-10-31)

Физический перенос **без** junction/symlink/mklink.

## До

| Область | Содержимое |
|---------|------------|
| `F:\MCP_Distr\` | Docker MCP: compose-1c, graph, compose-codeindex, bases, servers, … |
| `F:\AI_1C\upstream\` (корень) | 7 git-клонов: 1c_mcp, ai_rules_1c, … |
| `F:\AI_1C\MCP_VypolnenieKoda\` | Свой репозиторий компонента execute_code |
| `F:\AI_1C\` | harness, projects, upstream, MCP_VypolnenieKoda, README.md |

## После

```
F:\AI_1C\
  harness\
  projects\          (+ mcp-vypolnenie-koda, mcp-vypolnenie-koda_dev worktree)
  upstream\
    README.md
    git\               ← 8 репозиториев (7 + MCP_VypolnenieKoda)
    mcp\               ← бывший MCP_Distr
  README.md

F:\MCP_Distr\
  MOVED.md             ← указатель на upstream\mcp (не ссылка)
```

### `upstream\git\`

1c-formsserver, 1c_mcp, ai_rules_1c, cc-1c-skills, code-index-mcp, MCP_VypolnenieKoda, v8std, vanessa-automation.

### `upstream\mcp\` (верхний уровень)

bases, compose-1c, compose-codeindex, graph, Graph_metadata_search, docs, scripts, servers, old, config.env, INSTALL.md, …

В compose и `config.env` пути `F:/MCP_Distr/...` заменены на `F:/AI_1C/upstream/mcp/...` (17 файлов в дереве mcp).

## Docker

Compose-проекты (имена без изменений):

| Проект | Compose |
|--------|---------|
| 1c | `F:\AI_1C\upstream\mcp\compose-1c\docker-compose.yml` |
| 2graph | `F:\AI_1C\upstream\mcp\graph\docker-compose.yml` |
| 3codeindex | `F:\AI_1C\upstream\mcp\compose-codeindex\docker-compose.yml` |

После переноса: `docker compose stop` (старые пути) → move → `up -d --force-recreate` (новые пути). На момент отчета: 16 контейнеров Up, `graph_mcp` healthy.

## Harness (правки)

| Файл | Изменение |
|------|-----------|
| `docs/12_Docker_общие_MCP.md` | пути mcp |
| `docs/02_MCP.md`, `docs/08_Первый_запуск.md` | пути graph/docs |
| `docs/03_MCP_1С.md`, `docs/11`, `docs/14` | upstream/git, MCP_VypolnenieKoda |
| `docs/16_MCP_VypolnenieKoda.md` | **новый** dev/deploy |
| `scripts/check-upstream-releases.ps1` | compose paths |
| `scripts/upstream-watchlist.json` | git/*, GitHub MCP_VypolnenieKoda |
| `scripts/git-sync-run.ps1` | **новый** |
| `scripts/mcp/sync-mcp-vypolnenie-koda.ps1` | **новый** |
| `VERSION` | 1.4.10 |

## MCP_VypolnenieKoda

- Canonical: `F:\AI_1C\upstream\git\MCP_VypolnenieKoda` (main)
- Dev: `F:\AI_1C\projects\mcp-vypolnenie-koda_dev` (worktree, develop)
- Обвязка: `F:\AI_1C\projects\mcp-vypolnenie-koda\`
- Корень `F:\AI_1C\` без папки репозитория (clean root)

## Риски / хвосты

- Старые одноразовые скрипты в `mcp\scripts\` могут ссылаться на устаревшие пути в комментариях (INSTALL.md внутри mcp).
- `help_mcp-1c` health: starting — дождаться healthcheck после пересоздания.
- CFE в `build/` репозитория: sync копирует в `tools/mcp1c` при наличии файла после смены SHA main.
