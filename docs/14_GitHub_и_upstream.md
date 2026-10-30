# GitHub линии 1С и каталог upstream

## Репозитории линии (наши)

| Что | URL |
|-----|-----|
| Harness 1С | https://github.com/chubajs12/AI_1C_harness |
| MCP_ВыполнениеКода | https://github.com/chubajs12/MCP_VypolnenieKoda |
| Harness Apps (не‑1С) | https://github.com/chubajs12/AI_Apps_harness |

Локально: `F:\AI_1C\harness`, `F:\AI_1C\MCP_VypolnenieKoda`, `F:\AI_Apps\harness`.

В `MCP_VypolnenieKoda` каталог `build/` в git **не** коммитить (см. `.gitignore`).

## Клоны `F:\AI_1C\upstream\*`

| Папка | origin | Назначение | Обновление |
|-------|--------|------------|------------|
| `1c_mcp` | https://github.com/vladimir-kharin/1c_mcp.git | коробка MCP_Сервер | `gh release` / tag → `tools/mcp1c` |
| `1c-formsserver` | https://github.com/desko77/1c-formsserver.git | forms MCP | tag/commit; образ Docker Hub `desko77/1c-formsserver` |
| `ai_rules_1c` | https://github.com/comol/ai_rules_1c.git | rules/skills comol | commit/tag → выборочно в `harness/rules\|skills` |
| `cc-1c-skills` | https://github.com/Nikolay-Shirokov/cc-1c-skills.git | skills | tag → выборочно skills |
| `code-index-mcp` | https://github.com/Regsorm/code-index-mcp.git | bsl-indexer | release → bump `BSL_INDEXER_VERSION` / rebuild `*-code-index` |
| `v8std` | https://github.com/zeegin/v8std.git | стандарты | tag; образ `ghcr.io/zeegin/v8std-mcp` |
| `vanessa-automation` | https://github.com/Pr-Mex/vanessa-automation.git | Vanessa | **release** → `tools/vanessa` |

## Daily check

Дизайн: `docs/11_Upstream_релизы.md`.  
Скрипт dry-run: `scripts/check-upstream-releases.ps1` + манифест `scripts/upstream-watchlist.json` (те же репы + MCP‑пакетные источники).

Политика по умолчанию: **notify always**. Schedule / auto-pull whitelist — только после явного «да».  
Образы comol без публичного git (help/ssl/templates/syntaxcheck/graph) — не в watchlist git; обновление через `docs/12` / `docs/13` и `docker pull`.
