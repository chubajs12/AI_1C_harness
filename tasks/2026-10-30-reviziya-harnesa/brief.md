# Ревизия харнеса линии 1С (30.10.2026)

Чат про устройство харнеса `F:\AI_1C\harness`: правила, пути, MCP, Docker-зоны, перенос проектов, GitHub.

## Решение

Харнес на `F:\AI_1C\harness` (git `AI_1C_harness`). Версия: 1.4.7. Проекты — `F:\AI_1C\projects\`.

## Приемка (факт на 30.10.2026 ~23:10 MSK)

- [x] Публичный `MCP_VypolnenieKoda` — https://github.com/chubajs12/MCP_VypolnenieKoda ; ссылки в `docs/03`, `tools/mcp1c`, `docs/14`
- [x] Запасной канал толстого клиента убран (1.4.6)
- [x] Ссылка Vanessa: https://github.com/Pr-Mex/vanessa-automation
- [x] Upstream клоны в `F:\AI_1C\upstream` (см. `docs/14`)
- [x] `gh` auth chubajs12 — рабочий; harness https://github.com/chubajs12/AI_1C_harness
- [x] Правило «чистить за собой» — `temp/` + AGENTS.md п.13
- [x] Перенос dolea / mirax / rostviplast / energy → `F:\AI_1C\projects\` (+ `*_src` / `energy_ext_src`)
- [x] Docker зоны: **1c** / **2graph** / **3codeindex** (`docs/12`, `docs/13`)
- [ ] ПДн — блок правил/чеклиста из статьи ещё не заполнен (источник статьи не приложен)
- [ ] Daily upstream check — дизайн+скрипт есть; **schedule/автопилот** только после «да»
- [ ] vpn Cursor → junction на Apps — **blocker**: папка залочена сессией; канон `F:\AI_Apps\projects\vpn-server`
- [ ] Свежий Designer Dump conf/ext и полный `ready` conf-индекса dolea/rvp/energy — в процессе / не Dump

## Учет

- Метка: ai-assisted
- Сессия: 30.10.2026
