# Общие Docker MCP линии 1С

Канон дистрибутива пакетов: `D:\хлам\1c\ИИ\YYYY_MM_DD MCP_Distr` (актуально `2026_10_21`), живая копия инструкций — `F:\MCP_Distr`. Секреты только в `F:\MCP_Distr\graph\.env` и `config.env` (не в git харнеса).

## Общие контейнеры (не останавливать «заодно» под один проект)

| Имя контейнера | Образ (канон после 27.09.2026) | Порт | Назначение |
|----------------|--------------------------------|------|------------|
| `syntaxcheck_mcp-1c` | `comol/1c_syntaxcheck_mcp:latest` | 8002 | синтаксис BSL |
| `help_mcp-1c` | `comol/1c_help_mcp:light` | 8003 | справка платформы |
| `templates_mcp-1c` | `comol/template-search-mcp:light` | 8004 | шаблоны / remember |
| `graph_mcp` | `comol/1c_graph_metadata:light` | 8006 | граф метаданных |
| `ssl_mcp-1c` | `comol/mcp_ssl_server:light` | 8008 | БСП |
| `forms_mcp-1c` | `desko77/1c-formsserver:latest` | 8011 | Form.xml |
| `v8std_mcp-1c` | `ghcr.io/zeegin/v8std-mcp:stable` | 18766 | стандарты v8std |

Compose-проект графа: **`2graph`** (`F:\MCP_Distr\graph\docker-compose.yml`). Также: `graph_neo4j` (7474/7687), `graph_ollama` (11434), `graph_registrar`.

Теги `*-beta` после 27.09.2026 не публикуются — обновление: `docker pull` канон-тега → `docker stop` → `docker rename …_backup_YYYYMMDD` → `docker run` с теми же `-e`/`-v`/`-p` (без `docker rm` чужих стеков).

## Данные / индексы

| Что | Путь на хосте |
|-----|----------------|
| Состояние графа + Neo4j | `F:\MCP_Distr\bases\graph_stable\` (`neo4j_data`, `mcp_state`) |
| Ollama модели | `F:\MCP_Distr\bases\ollama` |
| Help/docs индекс | `F:\MCP_Distr\bases\mcp_docs_beta` (том контейнера help) |
| Индекс кода **проекта** | `F:\AI_1C\projects\<имя>\indexes\code-index\{home,conf,ext}` |
| Сырцы для индекса/графа | `F:\AI_1C\projects\<имя>_src\conf` и `ext` (ro) |

Индексатор кода — **свой** контейнер `<имя>_code_index` (не общий). Порты: dolea `8013`, rostviplast `8042`, mirax `8052`, energy `8041` (чужой контур — не трогать без задачи).

## Граф: тома проектов (host → container)

См. `F:\MCP_Distr\graph\docker-compose.yml`. После переноса линии 1С:

- dolea: `F:/AI_1C/projects/dolea_src/...`
- rostviplast: `F:/AI_1C/projects/rostviplast_src/...`
- mirax: `F:/AI_1C/projects/mirax_src/...`
- energy (пока): `F:/AI_DeepSeek/AI_1C/projects/energy_ext_src/...`

Реестр `project_id`: `F:\MCP_Distr\graph\registrar\projects.json`. Пересоздание только сервиса `mcp`:  
`docker compose -f F:\MCP_Distr\graph\docker-compose.yml --env-file F:\MCP_Distr\graph\.env up -d mcp`.

## MCP 1С в базе (не Docker)

Компонент `MCP_ВыполнениеКода`: https://github.com/chubajs12/MCP_VypolnenieKoda  
Коробка `MCP_Сервер`: https://github.com/vladimir-kharin/1c_mcp  
Дистрибутив CFE/EPF: `F:\AI_1C\harness\tools\mcp1c`.
