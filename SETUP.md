# Инструкция по работе с Laravel Boilerplate

Этот boilerplate предназначен для быстрого развертывания Laravel-проекта с архитектурой **PHP-FPM 8.5 + Apache Httpd 2.4 (Unix Socket)**, где база данных и Redis — **внешние** (не входят в Docker Compose).

---

## Содержание

1. [Для каких приложений подходит](#для-каких-приложений-подходит)
2. [Структура проекта](#структура-проекта)
3. [Быстрый старт (Development)](#быстрый-старт-development)
4. [Работа с окружениями](#работа-с-окружениями)
5. [Команды Makefile](#команды-makefile)
6. [Тестирование](#тестирование)
7. [Production-деплой](#production-деплой)
8. [Архитектура Docker](#архитектура-docker)
9. [Конфигурация сервисов](#конфигурация-сервисов)
10. [SSL/TLS (HTTPS)](#ssltls-https)
11. [Troubleshooting](#troubleshooting)

---

## Для каких приложений подходит

### Blade-based приложения
Классический Laravel: Blade templates, server-side rendering, Tailwind/Bootstrap.
**Примеры:** CRM, админки, корпоративные сайты, SaaS-панели, internal tools.

### Laravel + Livewire / Inertia
Frontend внутри Laravel: Livewire, Inertia + Vue/React. JS живёт в `resources/`, Vite используется только для сборки.

### API-only backend
Laravel как REST / GraphQL API без UI. Один сервис, простая деплой-модель.

**Итог:** подходит для Blade, Livewire, Inertia, API-only, Admin panels, Small–medium SaaS.

---

## Структура проекта

```text
├── docker/
│   ├── php.pgsql.Dockerfile      # PHP с расширениями для PostgreSQL
│   ├── php.mysql.Dockerfile      # PHP с расширениями для MySQL
│   ├── httpd.Dockerfile          # Apache Httpd 2.4 Alpine
│   ├── php/
│   │   ├── php.ini               # PHP конфиг для разработки (display_errors = On)
│   │   ├── php.prod.ini          # PHP конфиг для production (display_errors = Off, OPCache max)
│   │   └── www.conf              # PHP-FPM pool (Unix Socket, healthcheck ping)
│   └── httpd/
│       └── conf/
│           └── httpd.conf        # Apache vhost (mod_proxy_fcgi, RewriteEngine)
├── docker-compose.yml            # Dev-конфигурация (PHP, Apache, Node/Vite, Queue, Scheduler)
├── docker-compose.prod.yml       # Prod-конфигурация для деплоя (Dokploy и т.п.)
├── docker-compose.prod.local.yml # Локальный запуск prod-окружения (smoke test)
├── .dockerignore                 # Исключения из контекста сборки
├── .env.docker                   # Шаблон Docker-переменных для .env
├── .env.production.example       # Пример production-переменных
├── Makefile                      # Автоматизация всех операций
└── README.md / SETUP.md          # Документация
```

---

## Быстрый старт (Development)

### Предварительные требования

- **Docker** ≥ 24.0 и **Docker Compose** ≥ 2.20
- **Git**
- Доступ к внешним сервисам:
  - PostgreSQL / MySQL: `host:port`, база, пользователь, пароль
  - Redis: `host:port`, пароль (если есть)

### Шаг 1. Создание Laravel-проекта

```bash
composer create-project laravel/laravel my-project
cd my-project
```

### Шаг 2. Копирование файлов boilerplate

Скопируйте в корень Laravel-проекта:
- Папку `docker/` (со всеми подпапками)
- Файлы `docker-compose.yml`, `docker-compose.prod.yml`, `docker-compose.prod.local.yml`
- Файлы `Makefile`, `.dockerignore`, `.env.docker`, `.env.production.example`

### Шаг 3. Выбор Dockerfile для вашей БД

В boilerplate есть два варианта Dockerfile для PHP:
- `docker/php.pgsql.Dockerfile` — с расширениями для PostgreSQL
- `docker/php.mysql.Dockerfile` — с расширениями для MySQL

Переименуйте нужный в `php.Dockerfile` и удалите ненужный:

**Для PostgreSQL:**
```bash
mv docker/php.pgsql.Dockerfile docker/php.Dockerfile
rm docker/php.mysql.Dockerfile
```

**Для MySQL:**
```bash
mv docker/php.mysql.Dockerfile docker/php.Dockerfile
rm docker/php.pgsql.Dockerfile
```

### Шаг 4. Настройка конфигурационных файлов Laravel

#### Удаление лишних файлов

Laravel по умолчанию создаёт `database/database.sqlite`. В этом стеке используется внешняя БД, поэтому удалите файл и добавьте маску в `.gitignore`:

```bash
rm database/database.sqlite
```

Добавьте в `.gitignore`:

```text
database/*.sqlite
```

#### Обновление fallback-значений конфигурации

Laravel хранит дефолтные значения подключений в `config/`. По умолчанию они указывают на `sqlite` и `database`. Для корректной работы замените их на значения, соответствующие вашему стеку:

**`config/database.php`**
```php
// Для PostgreSQL:
'default' => env('DB_CONNECTION', 'pgsql'),
// Для MySQL:
'default' => env('DB_CONNECTION', 'mysql'),
```

**`config/queue.php`**
```php
'default' => env('QUEUE_CONNECTION', 'redis'),
// ...
'batching' => [
    'database' => env('DB_CONNECTION', 'pgsql'), // или 'mysql'
],
'failed' => [
    'database' => env('DB_CONNECTION', 'pgsql'), // или 'mysql'
],
```

**`config/cache.php`**
```php
'default' => env('CACHE_STORE', 'redis'),
```

**`config/session.php`**
```php
'driver' => env('SESSION_DRIVER', 'redis'),
```

> **Примечание:** Миграция `create_cache_table` создаёт таблицу `cache` в БД, но при `CACHE_STORE=redis` она не используется. Её можно удалить для чистоты или оставить как fallback.

### Шаг 5. Настройка .env

Откройте `.env` и внесите изменения:

```dotenv
# --- Подключение к внешней БД ---
# PostgreSQL:
DB_CONNECTION=pgsql
DB_HOST=<postgres_host>
DB_PORT=5432
DB_DATABASE=laravel
DB_USERNAME=postgres
DB_PASSWORD=password

# MySQL:
# DB_CONNECTION=mysql
# DB_HOST=<mysql_host>
# DB_PORT=3306
# DB_DATABASE=laravel
# DB_USERNAME=root
# DB_PASSWORD=password

# --- Redis ---
REDIS_HOST=<redis_host>
REDIS_PORT=6379
REDIS_PASSWORD=

QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
CACHE_STORE=redis

# --- Docker-переменные (из .env.docker) ---
HTTPD_PORT=8050

XDEBUG_MODE=off
XDEBUG_START=no
XDEBUG_CLIENT_HOST=host.docker.internal
```

> **Важно:** В external-модели Laravel **не создаёт базы данных** автоматически. `php artisan migrate` создаёт только таблицы. Базу нужно создать заранее вручную.

### Шаг 6. Запуск

```bash
make setup
```

Эта команда автоматически:
1. Соберёт Docker-образы
2. Запустит контейнеры (PHP-FPM, Apache Httpd, Queue Worker, Scheduler, Node HMR)
3. Установит зависимости (Composer + NPM)
4. Сгенерирует `APP_KEY`
5. Запустит миграции
6. Настроит права доступа

**Готово!** Проект доступен на http://localhost:8050 (или порт из `HTTPD_PORT`).

---

## Работа с окружениями

### Development (по умолчанию)

```bash
make up          # Запустить
make down        # Остановить
make restart     # Перезапустить
make logs        # Логи всех сервисов
```

Особенности dev-режима:
- Код монтируется из хоста (изменения применяются мгновенно)
- Vite HMR для горячей перезагрузки фронтенда
- Порт Apache Httpd проброшен наружу (по умолчанию `8050`)
- Xdebug установлен и включается через `.env`
- `php.ini` с `display_errors = On`

### Production (локальный smoke test)

```bash
cp .env.production.example .env.production
make up-prod
make logs-prod
```

Особенности prod-режима:
- Локальный запуск через `docker-compose.prod.local.yml`
- `php.prod.ini`: `display_errors = Off`, OPCache без проверки timestamps
- `composer install --no-dev --optimize-autoloader` внутри образа
- Автоматические миграции при старте PHP-контейнера
- Queue Worker и Scheduler из тех же образов
- Graceful shutdown (`STOPSIGNAL SIGQUIT`)

### Production (деплой через Dokploy)

Используется `docker-compose.prod.yml` — без проброса портов, порты управляются через Dokploy.

---

## Команды Makefile

### Управление контейнерами

| Команда | Описание |
|---------|----------|
| `make up` | Запустить проект (dev) |
| `make up-prod` | Запустить проект (prod, локально) |
| `make down` | Остановить dev-контейнеры |
| `make down-prod` | Остановить prod-контейнеры |
| `make restart` | Перезапустить контейнеры |
| `make build` | Собрать образы |
| `make rebuild` | Пересобрать dev-образы без кэша |
| `make rebuild-prod` | Пересобрать prod-образы без кэша |
| `make status` | Статус контейнеров |
| `make clean` | Удалить контейнеры и тома |
| `make clean-all` | Полная очистка dev (+ образы) |
| `make dev-reset` | Сброс среды разработки |
| `make clean-prod` | Удалить prod-контейнеры и тома |
| `make clean-all-prod` | Полная очистка prod (+ образы) |
| `make prod-reset` | Сброс prod-среды |

### Логи

| Команда | Описание |
|---------|----------|
| `make logs` | Все dev-сервисы |
| `make logs-prod` | Все prod-сервисы |
| `make logs-php` | PHP-FPM |
| `make logs-php-prod` | PHP-FPM (prod) |
| `make logs-httpd` | Apache Httpd |
| `make logs-httpd-prod` | Apache Httpd (prod) |
| `make logs-queue` | Queue Worker |
| `make logs-queue-prod` | Queue Worker (prod) |
| `make logs-scheduler` | Scheduler |
| `make logs-scheduler-prod` | Scheduler (prod) |
| `make logs-node` | Node (HMR) |

### Shell-доступ

| Команда | Описание |
|---------|----------|
| `make shell-php` | Консоль PHP-контейнера |
| `make shell-php-prod` | Консоль PHP-контейнера (prod) |
| `make shell-httpd` | Консоль Apache Httpd |
| `make shell-httpd-prod` | Консоль Apache Httpd (prod) |
| `make shell-node` | Консоль Node |
| `make shell-queue` | Консоль Queue Worker |
| `make shell-queue-prod` | Консоль Queue Worker (prod) |
| `make shell-scheduler` | Консоль Scheduler |
| `make shell-scheduler-prod` | Консоль Scheduler (prod) |

### Laravel и зависимости

| Команда | Описание |
|---------|----------|
| `make setup` | Полная инициализация проекта |
| `make install-deps` | Установить Composer + NPM зависимости |
| `make artisan CMD="..."` | Любая artisan-команда |
| `make composer CMD="..."` | Любая composer-команда |
| `make composer-install` | `composer install` |
| `make composer-update` | `composer update` |
| `make composer-require PACKAGE=vendor/pkg` | `composer require` |
| `make migrate` | Запустить миграции |
| `make rollback` | Откатить миграции |
| `make fresh` | Пересоздать БД + сиды |
| `make tinker` | Laravel Tinker |
| `make test-php` | PHP-тесты |
| `make test-coverage` | Тесты с покрытием |
| `make npm-install` | `npm install` |
| `make npm-dev` | Vite dev server |
| `make npm-build` | Production-сборка фронтенда |
| `make permissions` | Исправить права `storage` и `bootstrap/cache` |
| `make info` | Показать информацию о проекте |
| `make validate` | Проверить HTTP-доступность |

---

## Тестирование

```bash
make test-php
make test-coverage
```

Для покрытия используется Xdebug.

---

## Production-деплой

### Локальная проверка (smoke test)

```bash
cp .env.production.example .env.production
make up-prod
make logs-prod
```

### Деплой через Dokploy

Используется `docker-compose.prod.yml`. Порты не пробрасываются — управление через Dokploy.

Что важно проверить перед деплоем:
- Актуальные значения `APP_URL`, `APP_KEY`, `DB_*`, `REDIS_*`
- Доступность внешней БД и Redis из контейнерной сети
- Настройки TLS-терминации на уровне Dokploy

---

## Архитектура Docker

### Схема взаимодействия

```text
                    ┌─────────────┐
                    │   Client    │
                    └──────┬──────┘
                           │ :80 / :8050
                    ┌──────▼──────┐
                    │ Apache Httpd│
                    │ 2.4 (Alpine)│
                    └──────┬──────┘
                           │ Unix Socket
                    ┌──────▼──────┐
                    │   PHP-FPM   │
                    │ (8.5 Alpine)│
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
     ┌──────────────┐ ┌────────┐ ┌──────────┐
     │ PostgreSQL / │ │ Redis  │ │ Queue /  │
     │    MySQL     │ │(external)│ │Scheduler │
     │  (external)  │ └────────┘ └──────────┘
     └──────────────┘
```

### Ключевая идея

Apache Httpd проксирует PHP-запросы в PHP-FPM через Unix Socket (`/var/run/php/php-fpm.sock`) с помощью `mod_proxy_fcgi`. БД и Redis — внешние сервисы, подключаемые через переменные окружения. Это позволяет использовать managed-сервисы или выделенные серверы для инфраструктуры.

---

## Конфигурация сервисов

### PHP-FPM
- Базовый runtime Laravel-приложения
- В dev-режиме монтирует код проекта
- В prod-режиме собирается как финальный immutable image

### Apache Httpd
- Обслуживает публичные ассеты
- Проксирует PHP через `mod_proxy_fcgi` (FastCGI over Unix Socket)
- Использует конфигурацию из `docker/httpd/conf/httpd.conf`
- Event MPM для высокой производительности

### Node (dev only)
- Vite HMR для горячей перезагрузки фронтенда

### Queue Worker / Scheduler
- Отдельные сервисы для фоновых задач Laravel
- Используют тот же PHP-образ

---

## SSL/TLS (HTTPS)

По умолчанию boilerplate работает по HTTP. Для production HTTPS обычно завершается:
- на уровне Dokploy / reverse proxy / ingress
- на балансировщике перед контейнерами

---

## Troubleshooting

### Сайт не открывается
- Проверьте `make status`
- Проверьте `make logs-httpd`
- Убедитесь, что порт `HTTPD_PORT` свободен

### Laravel не подключается к БД
- Проверьте `DB_HOST` — должен указывать на внешний хост БД
- Убедитесь, что БД доступна из контейнерной сети
- Убедитесь, что база данных создана заранее

### Redis недоступен
- Проверьте `REDIS_HOST` — должен указывать на внешний хост Redis
- Проверьте доступность из контейнерной сети
- Если задан пароль, убедитесь, что он совпадает

### Vite HMR не работает
- Проверьте `make logs-node`
- Убедитесь, что порт `5173` свободен

### Ошибки прав доступа
```bash
make permissions
```
