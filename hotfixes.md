## Что сейчас выглядит неконсистентно (и почему это важно)

Ниже — список проблем, которые с высокой вероятностью либо **ломают запуск**, либо создают «дрейф» между dev/prod, либо ведут к неожиданному поведению.

### 1) `Makefile`: синтаксическая ошибка в `check-files` (ломает `make up`)
В проверке файла `docker/php.pgsql.Dockerfile` строка обрывается на `exit` — это приведёт к ошибке парсинга `make`.

**Нужно исправить**: дописать `1)` и закрыть скобки.

---

### 2) `Makefile`: проверяется `.env`, но в проекте виден `.env.docker`
Сейчас `check-files` требует **`.env`**, однако в дереве проекта присутствует **`.env.docker`**. В итоге `make up` будет падать даже если всё реально готово к старту.

**Варианты исправления (выберите один):**
- (Рекомендуется) хранить шаблон `.env.docker` и в `setup`/`check-files` подсказывать/делать копирование в `.env`;
- либо изменить проверку, чтобы принимались **`.env` или `.env.docker`**.

---

### 3) `docker-compose.dev.yml`: `depends_on` у `laravel-httpd-socket` конфликтует по типу с базовым compose
В базовом `docker-compose.yml` у `laravel-httpd-socket` `depends_on` задан в формате **mapping** с `condition: service_healthy`, а в dev-файле — в формате **list**. При мердже compose-файлов это часто приводит к ошибке валидации/слияния или к тому, что условие healthcheck «теряется».

**Нужно исправить**: в dev-файле привести `depends_on` к тому же типу (mapping) и сохранить ожидание готовности PHP-FPM.

Дополнительно: если цель — чтобы httpd не стартовал до node/vite, можно добавить `service_started` для node, но **не заменять** ожидание healthcheck php-fpm.

---

### 4) `docker-compose.yml`: объявлена сеть `redis-cluster-dev`, но нигде не используется
Она помечена как `external: true`, то есть её отсутствие в Docker окружении будет путать пользователей («а где её создать?»), и при этом сеть не подключена ни к одному сервису.

**Нужно исправить**: либо удалить сеть из compose, либо реально подключить к нужным сервисам и описать в документации, как её создать.

---

### 5) `docker-compose.dev.yml`: `unix-socket` используется, но в dev-файле не объявлен (не ошибка, но “шероховатость”)
Это **не обязано** быть ошибкой, потому что том `unix-socket` объявлен в базовом `docker-compose.yml`, и merge это подхватит. Но для читабельности dev-файла (и чтобы его можно было запускать отдельно) можно:
- либо добавить объявление `unix-socket:` в `volumes:` dev-файла,
- либо явно документировать, что dev запускается только вместе с базовым compose.

---

### 6) `Makefile`: `.PHONY` содержит цели, которых нет
Например, объявлена `shell-postgres`, но соответствующей цели в файле нет.

**Нужно исправить**: либо добавить цель, либо убрать из `.PHONY`, чтобы не вводить в заблуждение.

---

## Минимально необходимые правки (с конкретными изменениями)

### 1) Исправить `Makefile` (критично)

```makefile
# ... existing code ...
check-files: ## Проверить наличие всех необходимых файлов
	@echo "$(YELLOW)Проверка файлов конфигурации...$(NC)"
	@test -f docker-compose.yml || (echo "$(RED)✗ docker-compose.yml не найден$(NC)" && exit 1)
	@test -f docker-compose.dev.yml || (echo "$(RED)✗ docker-compose.dev.yml не найден$(NC)" && exit 1)
	@test -f docker-compose.prod.yml || (echo "$(RED)✗ docker-compose.prod.yml не найден$(NC)" && exit 1)
	@test -f .env || test -f .env.docker || (echo "$(RED)✗ .env не найден (или .env.docker). Создайте .env на основе .env.docker$(NC)" && exit 1)
	@test -f docker/php.mysql.Dockerfile || (echo "$(RED)✗ docker/php.mysql.Dockerfile не найден$(NC)" && exit 1)
	@test -f docker/php.pgsql.Dockerfile || (echo "$(RED)✗ docker/php.pgsql.Dockerfile не найден$(NC)" && exit 1)
	@test -f docker/httpd.Dockerfile || (echo "$(RED)✗ docker/httpd.Dockerfile не найден$(NC)" && exit 1)
	@test -f docker/httpd/conf/httpd.conf || (echo "$(RED)✗ docker/httpd/conf/httpd.conf не найден$(NC)" && exit 1)
	@test -f docker/php/php.ini || (echo "$(RED)✗ docker/php/php.ini не найден$(NC)" && exit 1)
	@test -f docker/php/www.conf || (echo "$(RED)✗ docker/php/www.conf не найден$(NC)" && exit 1)
	@echo "$(GREEN)✓ Все файлы на месте$(NC)"
# ... existing code ...

.PHONY: help up down restart build rebuild logs status shell-php shell-httpd clean setup artisan migrate
# ... existing code ...
```


Что это делает:
- чинит оборванный `exit`;
- делает проверку окружения более честной: **принимает `.env` или `.env.docker`**;
- убирает из `.PHONY` цель, которой нет (пример — `shell-postgres`).

---

### 2) Исправить `depends_on` в `docker-compose.dev.yml` (важно для мерджа)

```yaml
services:
  # Настройки PHP для разработки (монтирование кода)
  laravel-php-httpd-socket:
    volumes:
      - .:/var/www/laravel
      - unix-socket:/var/run/php

  # Настройки Httpd для разработки
  laravel-httpd-socket:
    ports:
      - "${HTTPD_PORT}:80"
    volumes:
      - .:/var/www/laravel
      - unix-socket:/var/run/php
    depends_on:
      laravel-php-httpd-socket:
        condition: service_healthy
      laravel-node-httpd-socket:
        condition: service_started

  # Node.js для сборки фронтенда и Hot Module Replacement (HMR)
  laravel-node-httpd-socket:
    image: node:24-alpine
    container_name: laravel-node-httpd-socket
    working_dir: /var/www/laravel
    volumes:
      - .:/var/www/laravel
      - node_modules:/var/www/laravel/node_modules
    command: >
      sh -lc '
        # Установка зависимостей, если они отсутствуют
        if [ -f package-lock.json ]; then
          npm ci;
        else
          npm install;
        fi;

        # Запуск Vite в режиме разработки
        npm run dev -- --host 0.0.0.0 --port 5173
      '
    ports:
      - "5173:5173"
    networks:
      - laravel-httpd-socket-network

volumes:
  node_modules:
# ... existing code ...
```


Почему так:
- в dev-файле `depends_on` теперь того же типа, что и в базовом файле (mapping), и **не уничтожает** ожидание healthcheck PHP-FPM;
- добавлено ожидание запуска node (без healthcheck, просто `service_started`).

---

## Рекомендации “второй очереди” (не блокируют старт, но улучшают проект)

1) **Удалить или задействовать** `redis-cluster-dev` сеть в `docker-compose.yml`, и/или описать её создание в `SETUP.md/README.md`.
2) Явно описать в документации, что dev запускается как:
    - `docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d`  
      и что `docker-compose.dev.yml` сам по себе не является полноценной конфигурацией (если вы не добавите в него недостающие объявления томов/сетей).
3) Проверить, что переменная `HTTPD_PORT` действительно определена в `.env`/`.env.docker`, иначе проброс порта в dev будет падать.

---

Если дашь содержимое `README.md`, `SETUP.md`, `docker-compose.prod.yml` и Dockerfile’ов (`docker/httpd.Dockerfile`, `docker/php.*.Dockerfile`), я смогу сделать второй проход: **сверить dev/prod parity**, healthchecks, права на `storage`, и типовой набор Laravel переменных — и выдать более полный чек-лист консистентности.