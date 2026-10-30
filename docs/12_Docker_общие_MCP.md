# Docker MCP линии 1С: три зоны

Канон Docker Desktop — **три** compose‑проекта (не смешивать):

| Группа | Compose | Состав |
|--------|---------|--------|
| **1c** | `F:\MCP_Distr\compose-1c\docker-compose.yml` | Только общие MCP: help, ssl, templates, syntaxcheck, forms, v8std |
| **codeindex** | `F:\MCP_Distr\compose-codeindex\docker-compose.yml` | Только `*_code_index` (dolea, mirax, rostviplast, energy, buh_demo, smallbusiness, …) |
| **2graph** | `F:\MCP_Distr\graph\docker-compose.yml` | Только граф: `graph_mcp`, `graph_neo4j`, `graph_ollama`, `graph_registrar` |

**Запрещено:** класть `help_mcp` / прочие MCP в 2graph; класть `*_code_index` в 2graph.

Секреты: `F:\MCP_Distr\compose-1c\env\*.env`, `F:\MCP_Distr\graph\.env` — не в git харнеса.

## Политика обновления

1. `docker pull` / пересборка image.
2. `docker compose -f <файл> up -d <service>` — контейнер **заменяется**, без кучи `*_bak`.
3. Успешный старт → старые backup‑контейнеры `docker rm`.
4. Переход comol `*-beta` → `light`/`latest` только с **новым** `LICENSE_KEY` (vibecoding1c). Иначе ключ на новых образах = Invalid/withdrawn.

## 1c — общие MCP

| Контейнер | Порт | Роль |
|-----------|------|------|
| `syntaxcheck_mcp-1c` | 8002 | синтаксис BSL |
| `help_mcp-1c` | 8003 | справка платформы |
| `templates_mcp-1c` | 8004 | шаблоны / remember |
| `ssl_mcp-1c` | 8008 | БСП |
| `forms_mcp-1c` | 8011 | Form.xml |
| `v8std_mcp-1c` | 18766 | стандарты v8std |

`docker compose -f F:\MCP_Distr\compose-1c\docker-compose.yml up -d`

## codeindex — индексаторы кода

| Контейнер | Порт | Сырцы | Индекс |
|-----------|------|-------|--------|
| `dolea_code_index` | 8013 | `F:\AI_1C\projects\dolea_src` | `...\dolea\indexes\code-index` |
| `rostviplast_code_index` | 8042 | `...\rostviplast_src` | `...\rostviplast\indexes\code-index` |
| `mirax_code_index` | 8052 | `...\mirax_src` | `...\mirax\indexes\code-index` |
| `energy_code_index` | 8041 | `F:\AI_DeepSeek\AI_1C\projects\energy_ext_src` | `F:\AI_1C\projects\energy\indexes\code-index` |
| `buh_demo_code_index` | 8062 | `F:\AI_AstraCode\buh_demo_src` | `...\buh_demo\indexes\code-index` |
| `smallbusiness_code_index` | 8061 | `F:\AI_AstraCode\SmallBusiness_demo_src` | `...\SmallBusiness_demo\indexes\code-index` |

`docker compose -f F:\MCP_Distr\compose-codeindex\docker-compose.yml up -d`  
Переиндекс: `scripts\mcp\code-index\reindex.ps1` (демон не видит file events с Windows bind mount).

## 2graph — только граф (+ GPU‑эмбеддинги)

| Контейнер | Порт | Роль |
|-----------|------|------|
| `graph_mcp` | 8006 | граф метаданных |
| `graph_neo4j` | 7474 / 7687 | хранилище |
| `graph_ollama` | 11434 | локальные эмбеддинги на GPU |
| `graph_registrar` | — | дорегистрация `project_id` из `registrar/projects.json` |

### Локальная модель на видеокарте

1. `graph_ollama` (`ollama/ollama`) + volume `F:/MCP_Distr/bases/ollama` + NVIDIA device в compose.
2. `graph_mcp` → `EMBEDDING_API_BASE=http://ollama:11434/v1`, модель `qwen3-embedding:0.6b`, `ENABLE_ROUTINE_EMBEDDINGS=true`.
3. Эмбеддинги процедур идут **внутри** сети `2graph_default`, не в облако.
4. Chat‑LLM в текущем compose не подключена — только embeddings.

`docker compose -f F:\MCP_Distr\graph\docker-compose.yml --env-file F:\MCP_Distr\graph\.env up -d`

Реестр образов/источников: `docs/13_Docker_реестр_контейнеров.md`.
