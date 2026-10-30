# Реестр Docker‑контейнеров линии 1С

Обновлено 30.10.2026. Группы: **1c** / **codeindex** / **2graph** — см. `docs/12_Docker_общие_MCP.md`.

| Имя | Группа | Роль | Image | Откуда | Как обновлять |
|-----|--------|------|-------|--------|----------------|
| `syntaxcheck_mcp-1c` | 1c | синтаксис BSL | `comol/1c_syntaxcheck_mcp:latest-beta` | Docker Hub comol | `compose-1c up -d syntaxcheck`; daily-check образ; на `latest` нужен новый LICENSE |
| `help_mcp-1c` | 1c | справка 1С | `comol/1c_help_mcp:light-beta` | Docker Hub | то же |
| `templates_mcp-1c` | 1c | шаблоны | `comol/template-search-mcp:light-beta` | Docker Hub | то же |
| `ssl_mcp-1c` | 1c | БСП | `comol/mcp_ssl_server:light-beta` | Docker Hub | то же |
| `forms_mcp-1c` | 1c | Form.xml | `desko77/1c-formsserver:latest` | Docker Hub desko77; git `desko77/1c-formsserver` в upstream | pull + compose up; upstream watchlist |
| `v8std_mcp-1c` | 1c | стандарты | `ghcr.io/zeegin/v8std-mcp:stable` | GHCR; git `zeegin/v8std` | pull + compose up; upstream watchlist |
| `dolea_code_index` | codeindex | индекс dolea | `dolea-code-index:1.8.5` | local build `harness/scripts/mcp/code-index` + bin Regsorm/code-index-mcp | bump BSL_INDEXER_VERSION, rebuild, compose up; upstream `code-index-mcp` |
| `rostviplast_code_index` | codeindex | индекс РВП | `rostviplast-code-index:1.8.5` | local build | то же |
| `mirax_code_index` | codeindex | индекс mirax | `mirax-code-index:1.8.5` | local build | то же |
| `energy_code_index` | codeindex | индекс energy | `energy-code-index:1.8.5` | local build | то же |
| `buh_demo_code_index` | codeindex | индекс buh_demo | `buh_demo-code-index:1.8.5` | local build | то же |
| `smallbusiness_code_index` | codeindex | индекс УНФ demo | `smallbusiness-code-index:1.8.5` | local build | то же |
| `graph_mcp` | 2graph | граф метаданных | `comol/1c_graph_metadata:light` | Docker Hub | `graph compose up -d mcp` |
| `graph_neo4j` | 2graph | БД графа | `neo4j@sha256:7d8d70f78c0c…` | Docker Hub (pin digest) | осторожно; данные в `bases/graph_stable` |
| `graph_ollama` | 2graph | GPU embeddings | `ollama/ollama:latest` | Docker Hub | pull; модели в `bases/ollama` |
| `graph_registrar` | 2graph | реестр project_id | `python:3.10-slim` | Docker Hub | скрипт `registrar/register_projects.py` |

Daily upstream check (GitHub tags/releases): `docs/11_Upstream_релизы.md`, `scripts/upstream-watchlist.json` — для git‑источников (v8std, forms, code-index-mcp, 1c_mcp, vanessa, ai_rules). Образы comol без публичного git — сверка digest/`docker pull` по расписанию после «да».
