# Подключение MCP к клиенту агента

Порты в примерах — по умолчанию комплекта (`myproj`, индексатор 8061, MCP 1С 8095 `/myproj`, Vanessa 9880): заменить на
значения из `config\project.env.local`. Все серверы — обычный HTTP (streamable HTTP), без TLS, только localhost; без
авторизации все, кроме MCP 1С (`myproj-1c`): у него Basic-авторизация пользователем базы (USER/PASS из параметров).

| Клиент | Файл | Куда положить |
|--------|------|---------------|
| Claude Code | `claude-code.mcp.json` | `.mcp.json` в корне проекта; разрешить серверы (`enabledMcpjsonServers` в `.claude\settings.local.json`) |
| Cursor | `cursor.mcp.json` | `.cursor\mcp.json` проекта |
| OpenCode | `opencode.json` | `opencode.json` в корне проекта (раздел `mcp`) |
| Codex CLI | `codex.config.toml` | `~\.codex\config.toml` или `.codex\config.toml` проекта (раздел `mcp_servers`) |

- **MCP 1С и пароль.** Заголовок `Authorization: Basic <base64(USER:PASS)>` печатает
  `python scripts\mcp1c\mcp1c.py --headers`. Claude Code берет его сам (`headersHelper` — абсолютный путь к скрипту
  проекта, пароль в `.mcp.json` не попадает). Cursor, OpenCode и Codex читают заголовок из переменной окружения
  пользователя `MYPROJ_MCP1C_AUTH` (значение — `Basic …` из вывода `--headers`): задать ее в окружении Windows, а не
  вписывать значение в файл конфигурации, — файл может попасть в git.
- MCP 1С и Vanessa подключать к сессии агента необязательно: из чата их можно вызывать скриптами по HTTP
  (`scripts\mcp1c\mcp1c.py`, `scripts\vanessa\vac.py`, раннеры) — без карточек согласия клиента и с маскированием
  паролей в выводе. Подключение напрямую удобно для разовых запросов к базе (`execute_query`, `get_metadata_structure`).
- Запасной OneBridge (`docs/09`) — `http://127.0.0.1:<ONEBRIDGE_PORT>/mcp` без авторизации, только пока он запущен;
  постоянной записью в конфигурацию клиента его не добавлять.
- Коннекторы поднимаются при старте сессии: после правки конфигурации — перезапустить сессию/переподключить.
- Клиент не поддерживает HTTP-серверы — `python scripts\mcp\mcp_http.py <порт> <инструмент> '<json>'` (или прокси
  stdio→HTTP вида `mcp-remote`).
- Граф: из скриптов — адрес со слэшем на конце (`http://127.0.0.1:8006/mcp/`), во все инструменты — `project_id`.
