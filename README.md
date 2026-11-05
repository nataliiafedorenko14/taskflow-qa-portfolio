# TaskFlow — QA Automation Portfolio

> **Мой вклад ([Наталия Федоренко](https://github.com/nataliiafedorenko14))** — UI-автотесты на Swift/XCUITest
> в `ios/TaskFlowUITests/`:
>
> - `AuthUITests.swift` — авторизация: успешный логин, неверный пароль, пустые поля, сценарий admin
> - `RegistrationUITests.swift` — регистрация нового пользователя
> - `Utils.swift` — хелперы: очистка текстовых полей, обработка системного алерта «Save Password»
>   (interruption monitor)
>
> Практики: accessibility-идентификаторы вместо координат, явные ожидания (`waitForExistence`),
> изоляция тестов через сброс БД (`UITEST_FRESH`), отключение анимаций.
>
> Базовый стенд (FastAPI-сервер + iOS-приложение TaskFlow) — учебный проект
> [GSukh](https://github.com/GSukh), лицензия MIT.

---

# TaskFlow — QA Automation Playground

Учебный playground для обучения тестировщиков автоматизации. Состоит из:

- **Сервер + БД** — REST API (FastAPI + SQLite) для практики API-тестов и работы с БД (SQL).
- **iOS-приложение** — SwiftUI-приложение для UI-тестов (XCTest/XCUITest).

Тема — трекер задач команды (Mini Jira): проекты, задачи, роли, статусы, приоритеты,
теги, комментарии, поиск, фильтры, audit log, уведомления. На этой теме естественно
покрываются CRUD, авторизация, права доступа, сетевые ошибки и сложные сценарии.

---

## Быстрый старт (одна команда)

Нужен только `python3` (есть на macOS из Command Line Tools) и для сборки iOS — Xcode.

```bash
./run.sh
```

Скрипт создаст виртуальное окружение (`.venv`), установит зависимости, проинициализирует
БД с предсказуемыми seed-данными и запустит сервер на `http://127.0.0.1:8000`.

После старта будут доступны:

- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc
- **OpenAPI JSON:** http://localhost:8000/openapi.json (и в `docs/openapi.json`)
- **БД (файл):** `data/app.db` — открывается `sqlite3 data/app.db` или DB Browser for SQLite

Флаги `./run.sh`:

```bash
./run.sh --reset     # пересидировать БД к seed-базовому состоянию, затем запустить
./run.sh --clean     # удалить data/app.db и пересоздать
./run.sh --port 8001 # кастомный порт
./run.sh test        # запустить примеры API-тестов (pytest)
```

> Docker не нужен — используется встроенный SQLite (файл `data/app.db`), zero-config.

---

## Предсказуемые тестовые данные (seed)

Запросите список готовых пользователей: `GET http://localhost:8000/api/test/seed-info`

| email | пароль | роль | назначение |
|---|---|---|---|
| `admin@test.local` | `admin123` | admin | управление проектами, пользователями и участниками |
| `manager@test.local` | `manager123` | manager | создание и назначение задач |
| `member@test.local` | `member123` | member | работа со своими задачами |
| `readonly@test.local` | `readonly123` | viewer | только чтение — для негативных проверок прав (403) |
| `empty@test.local` | `empty123` | member | пользователь без проектов |

Также созданы: 3 проекта, ~30 задач (для пагинации), теги (`ios`, `automation`, `bug`,
`feature`, `api`, `ui`), комментарии, уведомления. `member@test.local` состоит только в
проекте **Mobile QA Automation** — запросы к чужому проекту дают `403`.

Сброс к этому состоянию в любой момент:

```bash
curl -X POST http://localhost:8000/api/test/reset
```

---

## API

Базовый префикс `/api`. Авторизация — Bearer JWT (получается на `/api/auth/login`).

### Auth
```
POST   /api/auth/register
POST   /api/auth/login        -> { access_token, token_type, user }
GET    /api/auth/me
```

### Users (admin)
```
GET    /api/users
GET    /api/users/{id}
PATCH  /api/users/{id}        # смена роли
```

### Projects
```
GET    /api/projects                      # только проекты, где вы участник
POST   /api/projects
GET    /api/projects/{id}
PATCH  /api/projects/{id}
DELETE /api/projects/{id}
GET    /api/projects/{id}/members
POST   /api/projects/{id}/members
DELETE /api/projects/{id}/members/{user_id}
GET    /api/projects/{id}/tasks
```

### Tasks
```
POST   /api/projects/{id}/tasks
GET    /api/tasks                          # фильтры + поиск + пагинация (ниже)
GET    /api/tasks/{id}
PATCH  /api/tasks/{id}
DELETE /api/tasks/{id}
```

Параметры `GET /api/tasks`: `status`, `priority`, `assignee_id`, `project_id`, `tag`,
`q` (поиск по title/description), `sort` (`-created_at` по умолчанию, поддерживаются
`created_at`, `updated_at`, `title`, `due_date` с префиксом `-` для убывания),
`page`, `page_size`. Ответ: `{ items, total, page, page_size }`.

### Comments / Tags / Notifications / Audit
```
GET    /api/tasks/{id}/comments
POST   /api/tasks/{id}/comments
GET    /api/tags
POST   /api/tags
POST   /api/tasks/{id}/tags
GET    /api/notifications
PATCH  /api/notifications/{id}
POST   /api/notifications/read-all
GET    /api/audit?entity_type=&entity_id=&limit=    # admin/manager
```

### Тестовые режимы (ядро для QA-сценариев ошибок)

Глобальный режим сети (действует на все последующие запросы, кроме управляющих эндпоинтов):

```bash
curl -X POST http://localhost:8000/api/test-controls/network-mode \
  -H 'Content-Type: application/json' -d '{"mode":"error500"}'
# mode: normal | slow | error500 | unauthorized | empty | invalid-json | conflict
curl -X POST http://localhost:8000/api/test-controls/network-mode/reset
```

Либо per-request через заголовок на любой запрос:

```
X-Test-Scenario: slow-response | server-error | unauthorized | empty-tasks | invalid-json | conflict
```

Поведение: `slow` — задержка ~3с; `error500` — 500; `unauthorized` — 401; `conflict` — 409;
`empty` — пустой массив `[]` на GET; `invalid-json` — битое тело (для тренировки обработки
ошибок парсинга). Управляющие эндпоинты (`/api/test*`, `/api/test-controls*`, `/health`,
`/docs`) всегда работают, чтобы можно было сбросить режим.

---

## Роли и права

- **admin** — всё; управление пользователями.
- **manager** — создаёт проекты/задачи, назначает исполнителей, управляет участниками проекта.
- **member** — видит свои проекты; создаёт/редактирует задачи; работает со своими.
- **viewer** — только чтение (для негативных проверок `403`).

Доступ к задачам проекта — только для его участников (или admin). Чужой проект → `403`.

---

## Что тренировать

**API**: регистрация/логин/JWT, CRUD задач/проектов/комментариев, фильтры/поиск/пагинация,
негативные сценарии (пустое название → 422, дубликат email → 409, чужой проект → 403,
просроченный/поддельный токен → 401, недопустимый статус → 422), контрактные проверки через
OpenAPI/Swagger, проверка идемпотентности, race condition, цепочки интеграции.

**БД**: подготовка тестовых данных через SQL, проверки состояния после API-вызовов
(`SELECT * FROM tasks WHERE id=?`, `SELECT COUNT(*) ...`), целостность связей, каскадное
удаление (нет «висячих» комментариев после удаления задачи), many-to-many тегов, audit log.

```bash
sqlite3 data/app.db "SELECT id,title,status,priority FROM tasks LIMIT 5;"
sqlite3 data/app.db ".tables"
```

**iOS UI**: доступ по accessibility-идентификаторам, `XCUIApplication`, ожидания загрузки,
списки, pull-to-refresh, модалки, клавиатура, dark mode, локализация (RU/EN), deep links
(`taskflow://task/{id}`), отображение retry при ошибке сети, state restoration.

---

## iOS-приложение

```bash
cd ios
./regen-ios.sh        # сгенерировать .xcodeproj через XcodeGen (один раз, brew install xcodegen)
open TaskFlow.xcodeproj
```

В Xcode: Run (Cmd+R) на симуляторе. Приложение стучится на `http://localhost:8000` (симулятор
видит `localhost` хоста). Базовый URL можно посмотреть/изменить; выбор сетевого режима —
экран **Profile → Developer**.

Accessibility-идентификаторы (для стабильных UI-тестов):

```
login.emailTextField, login.passwordTextField, login.submitButton, login.errorLabel
register.emailTextField, register.nameTextField, register.passwordTextField, register.submitButton
projects.list, projects.createButton
tasks.list, tasks.createButton, tasks.searchField, tasks.filterButton
task.titleTextField, task.descriptionTextField, task.statusPicker, task.priorityPicker,
task.assigneePicker, task.dueDateToggle, task.dueDatePicker, task.tagsField, task.saveButton,
task.deleteButton, task.commentTextField, task.addCommentButton, comments.list
profile.logoutButton, profile.networkMode.<mode>, profile.resetDBButton
error.retryButton, filters.tagField, filter.status.<status>, filter.priority.<priority>,
filter.doneButton, filters.clearButton
```

### Запуск тестов iOS

Unit-тесты (без сервера):

```bash
cd ios
xcodebuild -project TaskFlow.xcodeproj -scheme TaskFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:TaskFlowTests test
```

UI-тесты (нужен запущенный сервер `./run.sh`):

```bash
./run.sh &                 # в отдельном терминале
cd ios
xcodebuild -project TaskFlow.xcodeproj -scheme TaskFlow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:TaskFlowUITests test
```

UI-тесты запускают приложение с переменной окружения `UITEST_FRESH=1`, поэтому каждое
тестирование стартует с логаута и сброшенной seed-БД (тесты изолированы).

---

## Структура проекта

```
mobile-qa-automation-playground/
├── run.sh                 # одна команда запуска сервера
├── requirements.txt
├── server/                # FastAPI-приложение
│   ├── app/
│   │   ├── main.py         # инстанс FastAPI, middleware, lifespan-seed
│   │   ├── models.py       # ORM-модели (11 таблиц)
│   │   ├── schemas.py       # Pydantic-схемы
│   │   ├── security.py      # JWT + pbkdf2-хеширование
│   │   ├── permissions.py   # RBAC
│   │   ├── test_controls.py # сетевые режимы + X-Test-Scenario
│   │   ├── seed.py          # предсказуемые seed-данные
│   │   └── routers/         # auth, users, projects, tasks, comments, tags, ...
│   └── tests/test_smoke.py  # примеры API-тестов (pytest)
├── docs/openapi.json       # экспорт OpenAPI для контрактных тестов
└── ios/                    # SwiftUI-приложение + XCUITest
    ├── project.yml          # XcodeGen-спека
    ├── regen-ios.sh
    ├── TaskFlow.xcodeproj   # сгенерированный проект (коммитится)
    ├── TaskFlow/            # исходники приложения
    ├── TaskFlowTests/       # unit-тесты
    └── TaskFlowUITests/     # UI-тесты
```

---

## Пример E2E-сценария

1. `POST /api/auth/login` (admin) → токен.
2. `POST /api/projects` → проект; `POST /api/projects/{id}/tasks` → задача.
3. `PATCH /api/tasks/{id}` (смена статуса) → проверка `audit_log` и `notifications`.
4. `GET /api/tasks?status=in_progress&q=...` — фильтр + поиск.
5. Логин `readonly@test.local` → `DELETE /api/tasks/{id}` → ожидаемо `403`.
6. `sqlite3 data/app.db "SELECT status FROM tasks WHERE id=?;"` — проверка в БД.
7. В iOS: создать задачу через UI → проверить через API, что она создана.

---

## Куда развиваться (V3)

WebSocket real-time, офлайн-кеш, загрузка вложений, нагрузочные тесты, observability
(метрики/трейсинг), Alembic-миграции, CI (GitHub Actions) с прогоном API- и UI-тестов,
отчёты Allure.

## Замечание о безопасности

Пароли seed-пользователей открыто указаны для удобства обучения. Это локальный
учебный сервер — **не используйте эти данные где-либо ещё**. Хеширование паролей —
PBKDF2-HMAC-SHA256, токены — HS256 JWT.
