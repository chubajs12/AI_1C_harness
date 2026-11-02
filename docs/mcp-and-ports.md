# MCP и порты: канон харнеса

Канон портов: [config/ports-registry.yaml](../config/ports-registry.yaml) (редактировать YAML).  
Зеркало для скриптов без Python: `config/ports-registry.json` (синхронизировать: `python scripts/ports-registry-load.py config/ports-registry.yaml > config/ports-registry.json` через write_text в UTF-8).  
В `F:\AI_1C\projects\<имя>\config\project.env.local` задают **PROJECT**, базу, секреты и пути; **числа портов Vanessa, code-index, MCP 1С (IIS) и graph project_id** подставляет `Get-KitEnv` / `kitenv.env()` из реестра.

## Контур (как устроено)

```text
  Агент (Cursor / Claude)
        |  HTTP MCP (localhost)
        v
  +------------------+     +------------------------+
  | Docker, общие    |     | Свой контейнер         |
  | :8002 syntax     |     | <project>_code_index   |
  | :8003 docs       |     | CODE_INDEX_PORT        |
  | :8004 templates  |     +------------------------+
  | :8006 graph      |              ^
  | :8008 ssl        |              | conf/ext read-only
  | :8011 forms      |     F:\AI_1C\projects\<p>_src
  | :18766 v8std     |
  +------------------+
        |
        |  Basic USER/PASS
        v
  IIS 1c_mcp :8095  -->  /{MCP1C_APP}/hs/mcp  (MCP 1С в базе)
        |
        v
  Vanessa TM :VANESSA_MCP_PORT  +  TC :VANESSA_TC_PORT  (RDP vanessa, schtasks)
```

| Слой | Где живет | Кто настраивает |
|------|-----------|-----------------|
| Общие MCP | Docker на `MCP_HOST` (обычно 127.0.0.1), порты в `shared.docker_mcp` реестра | админ машины; агент **не** `docker rm` / не пересоздает |
| Граф | `:8006`, `project_id` из реестра проекта | `refresh_graph_project` после выгрузки |
| Индексатор | свой контейнер и `CODE_INDEX_PORT` | `scripts/mcp/code-index/start-code-index.ps1` |
| MCP 1С | общий сайт IIS `8095`, свое приложение `mcp1c_app` и пул | `scripts/mcp1c/install-mcp.ps1`, `doctor.ps1` |
| Vanessa | своя пара портов TM/TC, своя задача `VANESSA_LAUNCH_TASK` | `scripts/vanessa/restart-vanessa.ps1`, для dolea — `start-dolea.ps1` |

Проверка: `scripts/doctor.ps1` с `KIT_ENV_FILE` на проект.

## Vanessa: одна пара на один MCP-порт

На одном `VANESSA_MCP_PORT` — только один TestManager. Чужие процессы **не** останавливаются (`restart-vanessa.ps1` сверяет базу и порты в командной строке).

Зарезервировано вне харнеса (не трогать без явной просьбы):

| Контур | MCP | TC |
|--------|-----|-----|
| SmallBusiness_demo | 9880 | 1539 |

Проекты линии 1С — см. таблицу в `ports-registry.json` → `projects`.

## project.env.local (проект)

Обязательно:

- `HARNESS_ROOT=F:\AI_1C\harness`
- `PROJECT=<имя>` — ключ в `ports-registry.json`
- база, `USER`, `PASS` (не в git), `EXTENSION_NAME`, пути `SRC_ROOT`

Не дублировать в env (WARN в doctor): `VANESSA_MCP_PORT`, `VANESSA_TC_PORT`, `CODE_INDEX_PORT`, `MCP1C_PORT`.

Опционально: `HARNESS_PORTS_REGISTRY=<путь>` — если реестр не в `HARNESS_ROOT\config\`.

Клиент MCP (Cursor): `.cursor/mcp.json` — общие URL фиксированы; code-index и MCP 1С — из тех же портов, что реестр + env (см. [00_Подключить_проект.md](00_Подключить_проект.md)). **OneBridge / EPF-мост (в т.ч. `:1414`) в `mcp.json` не указывать** — канал в базу только MCP 1С на IIS (`shared.mcp1c_iis.port`, обычно **8095**).

## Проекты линии

Числа **Vanessa MCP**, **TestClient**, **code-index**, **`mcp1c_app`**, **graph project_id** — только в [config/ports-registry.yaml](../config/ports-registry.yaml) (ключ `PROJECT` в `project.env.local`). Дублировать порты проектов в этом файле не нужно.

Проверка окружения:

```powershell
$env:KIT_ENV_FILE = 'F:\AI_1C\projects\<PROJECT>\config\project.env.local'
F:\AI_1C\harness\scripts\doctor.ps1
```

Vanessa (после `KIT_ENV_FILE`):

```powershell
F:\AI_1C\harness\scripts\vanessa\restart-vanessa.ps1
# dolea: scripts\vanessa\start-dolea.ps1
```

Проверка MCP Vanessa (подставить `VANESSA_MCP_PORT` из doctor / реестра):

```powershell
python F:\AI_1C\harness\scripts\mcp\mcp_http.py <VANESSA_MCP_PORT> initialize '{}'
```

Разовая регистрация задачи планировщика (администратор):  
`scripts\vanessa\register-launch-task.ps1 -EnvFile ...\<PROJECT>\config\project.env.local`

## Связанные документы

- [02_MCP.md](02_MCP.md) — инструменты MCP
- [03_MCP_1С.md](03_MCP_1С.md) — IIS, пул, execute_code
- [04_Vanessa.md](04_Vanessa.md) — TM/TC, RDP, микрокоманды
- [08_Первый_запуск.md](08_Первый_запуск.md) — первичная настройка проекта
