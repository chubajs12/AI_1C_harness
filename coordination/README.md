# Сквозная шина Project-чатов

Источник истины: репозиторий `chubajs12/AI_1C_harness`, локально `F:\AI_1C\harness`, каталог `coordination/`.

Cursor Project не дает API «написать в соседний чат». Координатор видит своих workers и иногда агентов того же repo. Нейтральный канал, который проекты читают по одним правилам, лежит здесь. Проект (energy, dolea и остальные) протокол не копирует: в своих правилах только ссылка на этот файл.

Шина не реестр портов MCP и не каталог серверов. Порты: [docs/mcp-and-ports.md](../docs/mcp-and-ports.md) и `config/ports-registry.yaml`. Кратко, чем проект отличается от харнеса: [docs/mcp-in-projects.md](../docs/mcp-in-projects.md).

## Каталог

```text
coordination/
  README.md                 # этот протокол
  inbox/
    energy.jsonl            # входящие для Project Energy
    dolea.jsonl
    harness.jsonl
  outbox-archive/           # по желанию: перенос ack-сообщений по месяцам
  threads/
    <yyyy-mm-dd-тема>/
      meta.yaml             # участники, тема, статус
      log.jsonl             # все сообщения треда
```

Пустые `inbox/*.jsonl` в git есть сразу. `outbox-archive/` и `threads/` появляются вместе с реальной перепиской, не заранее под конкретную задачу.

## Формат одной строки (`*.jsonl`, UTF-8)

```json
{
  "id": "msg-20261102-123456-abcd",
  "thread": "2026-11-02-vanessa-ports",
  "at": "2026-11-02T09:30:00Z",
  "from": { "project": "dolea", "agent": "bc-xxxxxxxx", "user": "chubajs12" },
  "to": { "project": "energy" },
  "type": "request|reply|notify|ack",
  "subject": "Задача Vanessa создана",
  "body": "tasks/2026-11-02-.... Кратко: ...",
  "refs": ["https://github.com/chubajs12/dolea/tasks/..."],
  "expectsReply": true,
  "replyTo": null
}
```

- Одна запись = append-only. Старые строки не правят.
- `type`: `request`, `reply`, `notify`, `ack`.
- ack: новая строка с `"type": "ack"` и `"replyTo": "<id>"`.
- `thread` связывает переписку (порты Vanessa, handoff и т.д.).
- Секреты в `body` и полях запрещены. Только ссылки на tasks/PR.
- Писать строку: `scripts/coordination/append-inbox.ps1`. Читать необработанные (нет ack): `scripts/coordination/read-inbox.ps1`.

## Роли Project-координаторов

| Действие | Когда |
|----------|--------|
| Прочитать `inbox/<свой-project>.jsonl` | Старт сессии, после явного запроса пользователя «сверь с dolea», по timer (см. ниже) |
| Записать в `inbox/<чужой-project>.jsonl` | Задача готова или нужен ответ соседа |
| Commit + push harness | Каждое сообщение или пачка за ход |

Правило для energy / dolea (коротко, без второй копии протокола):

> Cross-chat: не дублировать договоренности в чате. Исходящее — append в harness `coordination/inbox/<target>.jsonl`; входящее — обработать и `ack`. Источник истины: `F:\AI_1C\harness\coordination\README.md`.

На каждый ход то же сказано в `AGENTS.md` (раздел 2).

## Как оповестить соседа

1. Git (база). Push в harness. Соседний Project не узнает, пока не прочитает inbox (ручной старт, timer или пользователь скажет «проверь шину»).
2. `subscribe_timer` (Cloud Agent), в каждом Project при активной нитке:
   - `name`: `cross-chat-poll-harness`
   - `delaySeconds`: 900 (15 мин) или `cron`: `*/15 * * * *`
   - `prompt`: прочитать harness `coordination/inbox/<свой-project>.jsonl`; необработанные без ack показать пользователю, записать ack или делегировать worker. Уже показанное в чате не дублировать.
3. GitHub (громче, по желанию). Issue в harness с меткой `cross-chat`. Подписка `subscribe_github_pr` на комментарии issue не подходит: она про PR. Практичный компромисс: один постоянный issue «Cross-chat inbox», комментарий = «energy->dolea: msg-id ...»; второй Project по timer читает issue через `gh`, если это добавлено навыком.
4. Пользователь по-прежнему самый надежный канал: «dolea закончил, id ...». Координатор читает harness и подтверждает.

## Пример нитки (не запуск работ)

1. Dolea создает свою задачу и append в `inbox/energy.jsonl`: `notify`, `thread` с именем нитки.
2. Energy при следующем poll, timer или старте сессии видит сообщение и показывает его пользователю. Workers harness/dolea без ack пользователя не стартуют.
3. Energy отвечает append в `inbox/dolea.jsonl` (`reply` и ссылка на свою задачу).
4. Обе стороны пишут `ack` на исходные id.

Номера портов в сообщениях шины берут из уже записанного реестра харнеса. Шина новых портов не назначает.

## Ограничения

- Нет гарантии доставки быстрее 15 минут без timer или без слов пользователя.
- Конфликты git: append-only их снижает. При конфликте — rebase ветки harness.
- Секреты в body запрещены.
