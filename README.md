# Laravel Boilerplate (PHP-FPM + Apache Httpd Unix Socket + External DB + External Redis)

Этот репозиторий представляет собой **boilerplate** для развертывания Laravel-проектов с архитектурой **PHP-FPM + Apache Httpd через Unix Socket**. База данных и Redis — **внешние** (не поднимаются в Docker Compose).

## Особенности

*   **Производительность:** связь между Apache Httpd и PHP-FPM через **Unix Socket** (без TCP overhead).
*   **Гибкость БД:** поддержка **PostgreSQL** и **MySQL** (через выбор соответствующего Dockerfile).
*   **External infra:** БД и Redis — внешние, подключение через переменные окружения.
*   **Современный стек:**
    *   **PHP 8.5** (Alpine) — с предустановленными расширениями.
    *   **Apache Httpd 2.4** (Alpine) — оптимизированный конфиг для Laravel (Event MPM + mod_proxy_fcgi).
    *   **Node.js 24** — Vite с HMR (только в dev).
*   **Разделение окружений:** конфигурации для **Development** и **Production**.
*   **Xdebug:** включается одной переменной в `.env`.
*   **Makefile:** автоматизация всех рутинных операций.

## Структура проекта

*   `docker/` — Dockerfiles и конфигурации для PHP и Apache Httpd.
*   `docker-compose.yml` — Dev-конфигурация (PHP, Apache, Node/Vite, Queue, Scheduler).
*   `docker-compose.prod.yml` — Prod-конфигурация для деплоя (Dokploy и т.п.).
*   `docker-compose.prod.local.yml` — Локальный запуск prod-окружения (smoke test).
*   `Makefile` — Автоматизация операций.

## Быстрый старт (Development)

1.  Создайте проект Laravel:
    ```bash
    composer create-project laravel/laravel .
    ```
2.  Скопируйте файлы boilerplate в корень проекта.
3.  **Выберите Dockerfile** для вашей БД — переименуйте нужный в `php.Dockerfile`:
    *   Для **PostgreSQL**: `mv docker/php.pgsql.Dockerfile docker/php.Dockerfile`
    *   Для **MySQL**: `mv docker/php.mysql.Dockerfile docker/php.Dockerfile`
    *   Удалите ненужный Dockerfile.
4.  Настройте конфигурационные файлы Laravel (см. раздел ниже).
5.  Настройте `.env` (подключение к **внешней БД** и **внешнему Redis**).
6.  Запустите:
    ```bash
    make setup
    ```

**Готово!** Сайт доступен на http://localhost:8050 (или порт из `HTTPD_PORT`).

---

## Настройка конфигурационных файлов Laravel

### Удаление лишних файлов

Laravel по умолчанию создаёт `database/database.sqlite`. В этом стеке используется внешняя БД, поэтому удалите файл и добавьте маску в `.gitignore`:

```bash
rm database/database.sqlite
```

Добавьте в `.gitignore`:

```text
database/*.sqlite
```

### Обновление fallback-значений конфигурации

Laravel хранит дефолтные значения подключений в `config/`. По умолчанию они указывают на `sqlite` и `database`. Замените их на значения, соответствующие вашему стеку:

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

---

## База данных: создание и подключение

В external-модели Laravel **не создаёт базы данных** автоматически. `php artisan migrate` создаёт таблицы, но не делает `CREATE DATABASE`. Базу нужно создать заранее.

### PostgreSQL (.env)
```dotenv
DB_CONNECTION=pgsql
DB_HOST=<postgres_host>
DB_PORT=5432
DB_DATABASE=app1_db
DB_USERNAME=app1_user
DB_PASSWORD=<PASSWORD>
```

### MySQL (.env)
```dotenv
DB_CONNECTION=mysql
DB_HOST=<mysql_host>
DB_PORT=3306
DB_DATABASE=app1_db
DB_USERNAME=app1_user
DB_PASSWORD=<PASSWORD>
```

После изменения `.env` сбросьте кэш и запустите миграции:
```bash
php artisan config:clear
php artisan migrate
```

---

## Основные команды (Makefile)

*   `make up` — Запустить проект (dev).
*   `make up-prod` — Запустить проект (prod, локально).
*   `make down` — Остановить контейнеры.
*   `make setup` — Полная инициализация проекта.
*   `make artisan CMD="migrate"` — Выполнить команду artisan.
*   `make shell-php` — Войти в консоль PHP-контейнера.
*   `make logs` — Просмотр логов.
*   `make info` — Информация о проекте.

---

*Подробная инструкция по установке и настройке находится в [SETUP.md](SETUP.md).*
