# Проверка свежести upstream на GitHub

**Статус:** 31.10.2026 — ежедневный **notify dry-run** через Task Scheduler (`AI_1C_upstream_daily`, 07:00, `-SkipGh` если нет `gh auth`). Полный автопилот (auto-merge rules/skills/MCP, `-Apply`) — **только после явного «да»**.

## Цель

Раз в день смотреть, не вышли ли новые релизы/теги у зависимостей харнеса. Если свежее локальной копии — **сообщить** в контур проекта 1С harness. Обновление копий / принятие rules/skills/MCP — по политике ниже, не молча.

## Что мониторить

Клоны в `F:\AI_1C\upstream\` + локальный MCP-компонент:

| Локальная папка | GitHub | Что сравнивать | Куда обычно «принимать» |
|-----------------|--------|----------------|-------------------------|
| `ai_rules_1c` | comol/ai_rules_1c | latest commit / tag (часто без release) | `harness/rules`, `harness/skills` (выборочно) |
| `cc-1c-skills` | Nikolay-Shirokov/cc-1c-skills | tag / release | skills (выборочно) |
| `1c_mcp` | vladimir-kharin/1c_mcp | **release** / tag | `tools/mcp1c`, docs MCP |
| `vanessa-automation` | Pr-Mex/vanessa-automation | **release** / tag | `tools/vanessa` (single zip) |
| `code-index-mcp` | Regsorm/code-index-mcp | release / tag | Docker/индекс линия |
| `v8std` | zeegin/v8std | commit / tag | BSL LS / Docker |
| `1c-formsserver` | desko77/1c-formsserver | commit / tag | по необходимости |
| `F:\AI_1C\MCP_VypolnenieKoda` | (свой fork, когда появится remote) | release / tag | дистрибутив MCP 1С линии |

Образы Docker Hub без публичного git (graph/syntaxcheck и т.п.) — **вне** этого контура; отдельный чеклист digest’ов при необходимости.

### Источники обновлений MCP 1С (пакеты / дистрибутив)

Не GitHub-теги, а **поставки пакетов** для `tools/mcp1c` и установки в базу. В daily-check учитывать как отдельные каналы (сверка по дате файла / версии в имени `_vX_Y_Z`, не по git). **Credentials в docs и в git не писать** — вход на vibecoding1c / Я.Диск вручную или через уже сохранённую сессию пользователя.

| Источник | Тип | Примечание |
|----------|-----|------------|
| `D:\хлам\1c\ИИ` | локальная папка пакетов | Сверять новые/свежие архивы и CFE/EPF на диске |
| https://disk.yandex.ru/d/iJJvouaNLQs1sQ | Яндекс.Диск (публичная/шара) | После auth на vibecoding1c; пароли/токены сюда не класть |
| https://vibecoding1c.ru/mcpserver | сайт → **Скачать** | Каноническая страница загрузки MCP Server; логин отдельно |

Локальный git-компонент линии: `F:\AI_1C\MCP_VypolnenieKoda` (свой репозиторий, когда будет remote). Upstream-коробка: `1c_mcp` (vladimir-kharin) — см. таблицу выше.

Манифест для скрипта: `scripts/upstream-watchlist.json` (см. скелет). MCP-пакетные источники — блок `mcpPackageSources` в том же JSON.

## Как сравнивать

1. Для каждой записи: `gh release view --json tagName,publishedAt,url` **или**, если релизов нет, `gh api repos/{owner}/{repo}/tags` / `git ls-remote --tags`.
2. Локально: HEAD и ближайший tag клона в `upstream\<name>` (или pin в манифесте `pinnedTag` / `pinnedSha`).
3. «Свежее» = remote tag/release новее pin **или** remote default-branch tip ≠ локальный tip (для реп без тегов — только tip, с пометкой `commit-only`).
4. Нужен рабочий `gh auth` (или `GH_TOKEN`). Без auth — FAIL в отчёте, без догадок.

Скрипт: `scripts/check-upstream-releases.ps1` — по умолчанию **dry-run** (только отчёт, ничего не тянет).

## Куда писать уведомление

Пока (без schedule):

1. stdout + файл `temp/upstream-check-YYYYMMDD.md` (temp чистится после задачи).
2. Опционально дописать строку в `tasks/<актуальная>/log.md` харнеса, если запущено из задачи ревизии.
3. Позже (после «да» на автопилот): тот же отчёт → топик/чат проекта 1С harness (механизм доставки отдельно: TG bridge / Cursor task — не зафиксирован).

Текст уведомления: имя репо, локальный pin, remote latest, URL release/tag, рекомендация (`notify` / `whitelist-update`).

## Политика update (предложение)

| Режим | Поведение |
|-------|-----------|
| **A. notify always** (по умолчанию) | Только отчёт. Никаких `git pull`, копий в `rules/`/`skills/`, замены Vanessa/MCP. |
| **B. whitelist + подтверждение** | Для реп из `autoPullWhitelist` скрипт может сделать `git fetch` + показать diff/log; **применение** в harness — только после явного «да» человека (или `-Apply` после dry-run просмотра). |
| **C. dry-run apply** | Симуляция: «скопировал бы файлы X→Y», список путей, без записи. |

**Не делать без «да»:** ежедневный Task Scheduler; авто-merge comol rules поверх локальных правок; авто-bump VERSION харнеса; авто-деплой MCP в базы проектов.

Whitelist (черновик, пустой до решения): например только `vanessa-automation` (скачать release asset) и `1c_mcp` (обновить upstream clone) — rules/skills всегда ручной review.

## Расписание

Создано на машине агента (31.10.2026):

```text
schtasks /Query /TN AI_1C_upstream_daily
```

Пересоздание (интерактивный пользователь, gh keyring):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File F:\AI_1C\harness\scripts\register-upstream-daily-task.ps1
# без GitHub API:
powershell -NoProfile -ExecutionPolicy Bypass -File F:\AI_1C\harness\scripts\register-upstream-daily-task.ps1 -SkipGh
```

Задача вызывает `scripts/run-upstream-daily.ps1` (PATH/LOCALAPPDATA пользователя). Apply — отдельная команда/задача, не в schedule.

## Связанные файлы

- Скрипт: `scripts/check-upstream-releases.ps1`
- Список: `scripts/upstream-watchlist.json`
- Клоны: `F:\AI_1C\upstream\`
- Перенос dolea/rostviplast/mirax — **не** связан с этим требованием и по-прежнему отложен.
