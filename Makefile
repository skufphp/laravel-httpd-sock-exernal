# ==========================================
# Laravel PHP-FPM Apache Socket (Boilerplate)
# ==========================================

.PHONY: \
	help check-files check-files-prod \
	up up-prod down down-prod restart build rebuild rebuild-prod \
	logs logs-prod logs-php logs-php-prod logs-node logs-queue logs-queue-prod logs-scheduler logs-scheduler-prod logs-httpd logs-httpd-prod \
	status \
	shell-php shell-php-prod shell-node shell-queue shell-queue-prod shell-scheduler shell-scheduler-prod shell-httpd shell-httpd-prod \
	setup install-deps \
	composer-install composer-update composer-require \
	npm-install npm-dev npm-build \
	artisan composer migrate rollback fresh tinker test-php test-coverage \
	permissions info validate \
	clean clean-all dev-reset clean-prod clean-all-prod prod-reset

# Цвета для вывода
YELLOW=\033[0;33m
GREEN=\033[0;32m
RED=\033[0;31m
NC=\033[0m

# Переменные Compose
COMPOSE = docker compose -f docker-compose.yml
COMPOSE_PROD = docker compose --env-file .env.production -f docker-compose.prod.local.yml

HTTPD_PORT := $(shell grep '^HTTPD_PORT=' .env 2>/dev/null | cut -d '=' -f 2- | tr -d '[:space:]')
ifeq ($(HTTPD_PORT),)
HTTPD_PORT := 8050
endif

# Сервисы (имена сервисов из compose-файлов)
PHP_SERVICE=laravel-php-apache-uds-core
HTTPD_SERVICE=laravel-apache-uds-core
NODE_SERVICE=laravel-node-apache-uds-core
QUEUE_SERVICE=laravel-queue-apache-uds-core
SCHEDULER_SERVICE=laravel-scheduler-apache-uds-core

help: ## Показать справку
	@echo "$(YELLOW)Laravel PHP-FPM and Apache (Httpd) Docker Boilerplate with Unix Socket$(NC)"
	@echo "======================================"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

check-files: ## Проверить наличие всех необходимых файлов
	@echo "$(YELLOW)Проверка файлов конфигурации...$(NC)"
	@test -f docker-compose.yml || (echo "$(RED)✗ docker-compose.yml не найден$(NC)" && exit 1)
	@test -f docker-compose.prod.yml || (echo "$(RED)✗ docker-compose.prod.yml не найден$(NC)" && exit 1)
	@test -f .env || (echo "$(RED)✗ .env не найден. Убедитесь, что вы настроили проект Laravel$(NC)" && exit 1)
	@test -f docker/php.Dockerfile || (echo "$(RED)✗ docker/php.Dockerfile не найден$(NC)" && exit 1)
	@test -f docker/httpd.Dockerfile || (echo "$(RED)✗ docker/httpd.Dockerfile не найден$(NC)" && exit 1)
	@test -f docker/php/php.ini || (echo "$(RED)✗ docker/php/php.ini не найден$(NC)" && exit 1)
	@test -f docker/httpd/conf/httpd.conf || (echo "$(RED)✗ docker/httpd/conf/httpd.conf не найден$(NC)" && exit 1)
	@echo "$(GREEN)✓ Все файлы на месте$(NC)"

check-files-prod: ## Проверить наличие файлов для prod
	@echo "$(YELLOW)Проверка файлов конфигурации...$(NC)"
	@test -f docker-compose.prod.local.yml || (echo "$(RED)✗ docker-compose.prod.local.yml не найден$(NC)" && exit 1)
	@test -f .env.production || (echo "$(RED)✗ .env.production не найден. Создайте его из .env.production.example$(NC)" && exit 1)
	@test -f docker/php.Dockerfile || (echo "$(RED)✗ docker/php.Dockerfile не найден$(NC)" && exit 1)
	@test -f docker/httpd.Dockerfile || (echo "$(RED)✗ docker/httpd.Dockerfile не найден$(NC)" && exit 1)
	@test -f docker/php/php.prod.ini || (echo "$(RED)✗ docker/php/php.prod.ini не найден$(NC)" && exit 1)
	@test -f docker/httpd/conf/httpd.conf || (echo "$(RED)✗ docker/httpd/conf/httpd.conf не найден$(NC)" && exit 1)
	@echo "$(GREEN)✓ Все файлы на месте$(NC)"

up: check-files ## Запустить контейнеры (Dev)
	$(COMPOSE) up -d
	@echo "$(GREEN)✓ Проект запущен на http://localhost:$(HTTPD_PORT)$(NC)"

up-prod: check-files-prod ## Запустить контейнеры (Prod)
	$(COMPOSE_PROD) up -d
	@echo "$(GREEN)✓ Проект (Prod) запущен$(NC)"

down: ## Остановить контейнеры
	$(COMPOSE) down

down-prod: ## Остановить контейнеры (Prod)
	$(COMPOSE_PROD) down

restart: ## Перезапустить контейнеры
	$(COMPOSE) restart

build: ## Собрать образы (Dev)
	$(COMPOSE) build

rebuild: ## Пересобрать образы без кэша (Dev)
	$(COMPOSE) build --no-cache

rebuild-prod: ## Пересобрать prod образы без кэша
	$(COMPOSE_PROD) build --no-cache

logs: ## Показать логи
	$(COMPOSE) logs -f

logs-prod: ## Показать логи всех сервисов (Prod)
	$(COMPOSE_PROD) logs -f

logs-php: ## Просмотр логов PHP-FPM
	$(COMPOSE) logs -f $(PHP_SERVICE)

logs-php-prod: ## Просмотр логов PHP-FPM (Prod)
	$(COMPOSE_PROD) logs -f $(PHP_SERVICE)

logs-httpd: ## Просмотр логов Apache (Httpd)
	$(COMPOSE) logs -f $(HTTPD_SERVICE)

logs-httpd-prod: ## Просмотр логов Apache (Httpd) (Prod)
	$(COMPOSE_PROD) logs -f $(HTTPD_SERVICE)

logs-node: ## Просмотр логов Node (HMR)
	$(COMPOSE) logs -f $(NODE_SERVICE)

logs-queue: ## Просмотр логов Queue Worker
	$(COMPOSE) logs -f $(QUEUE_SERVICE)

logs-queue-prod: ## Просмотр логов Queue Worker (Prod)
	$(COMPOSE_PROD) logs -f $(QUEUE_SERVICE)

logs-scheduler: ## Просмотр логов Scheduler
	$(COMPOSE) logs -f $(SCHEDULER_SERVICE)

logs-scheduler-prod: ## Просмотр логов Scheduler (Prod)
	$(COMPOSE_PROD) logs -f $(SCHEDULER_SERVICE)

status: ## Статус контейнеров
	$(COMPOSE) ps

shell-php: ## Войти в контейнер PHP
	$(COMPOSE) exec $(PHP_SERVICE) sh

shell-php-prod: ## Войти в контейнер PHP (Prod)
	$(COMPOSE_PROD) exec $(PHP_SERVICE) sh

shell-httpd: ## Подключиться к контейнеру Apache (Httpd)
	$(COMPOSE) exec $(HTTPD_SERVICE) sh

shell-httpd-prod: ## Подключиться к контейнеру Apache (Httpd) (Prod)
	$(COMPOSE_PROD) exec $(HTTPD_SERVICE) sh

shell-node: ## Подключиться к контейнеру Node
	$(COMPOSE) exec $(NODE_SERVICE) sh

shell-queue: ## Войти в контейнер Queue Worker
	$(COMPOSE) exec $(QUEUE_SERVICE) sh

shell-queue-prod: ## Войти в контейнер Queue Worker (Prod)
	$(COMPOSE_PROD) exec $(QUEUE_SERVICE) sh

shell-scheduler: ## Войти в контейнер Scheduler
	$(COMPOSE) exec $(SCHEDULER_SERVICE) sh

shell-scheduler-prod: ## Войти в контейнер Scheduler (Prod)
	$(COMPOSE_PROD) exec $(SCHEDULER_SERVICE) sh

# --- Команды Laravel ---

setup: ## Полная инициализация проекта с нуля
	@make build
	@make up
	@make install-deps
	@make artisan CMD="key:generate"
	@make migrate
	@make permissions
	@echo "$(GREEN)✓ Проект готов: http://localhost:$(HTTPD_PORT)$(NC)"

install-deps: ## Установка всех зависимостей (Composer + NPM)
	@echo "$(YELLOW)Установка зависимостей...$(NC)"
	@$(MAKE) composer-install
	@$(MAKE) npm-install

# --- Команды Composer ---

composer-install: ## Установить зависимости через Composer
	$(COMPOSE) exec $(PHP_SERVICE) composer install

composer-update: ## Обновить зависимости через Composer
	$(COMPOSE) exec $(PHP_SERVICE) composer update

composer-require: ## Установить пакет через Composer (make composer-require PACKAGE=vendor/package)
	$(COMPOSE) exec $(PHP_SERVICE) composer require $(PACKAGE)

composer: ## Запустить команду composer (make composer CMD="install")
	$(COMPOSE) exec $(PHP_SERVICE) composer $(CMD)

# --- Команды NPM ---

npm-install: ## Установить NPM зависимости
	$(COMPOSE) exec $(NODE_SERVICE) npm install

npm-dev: ## Запустить Vite в режиме разработки (hot reload)
	$(COMPOSE) exec $(NODE_SERVICE) npm run dev

npm-build: ## Собрать фронтенд (внутри Node контейнера)
	$(COMPOSE) exec $(NODE_SERVICE) npm run build

# --- Команды Artisan ---

artisan: ## Запустить команду artisan (make artisan CMD="migrate")
	$(COMPOSE) exec $(PHP_SERVICE) php artisan $(CMD)

migrate: ## Запустить миграции
	$(COMPOSE) exec $(PHP_SERVICE) php artisan migrate

rollback: ## Откатить миграции
	$(COMPOSE) exec $(PHP_SERVICE) php artisan migrate:rollback

fresh: ## Пересоздать базу и запустить сиды
	$(COMPOSE) exec $(PHP_SERVICE) php artisan migrate:fresh --seed

tinker: ## Запустить Laravel Tinker
	$(COMPOSE) exec $(PHP_SERVICE) php artisan tinker

test-php: ## Запустить тесты PHP (PHPUnit)
	$(COMPOSE) exec $(PHP_SERVICE) php artisan test

test-coverage: ## Запустить тесты с покрытием кода
	$(COMPOSE) exec $(PHP_SERVICE) php artisan test --coverage

# --- Утилиты ---

permissions: ## Исправить права доступа для Laravel (storage/cache)
	@echo "$(YELLOW)Исправление прав доступа...$(NC)"
	$(COMPOSE) exec $(PHP_SERVICE) sh -c "if [ -d storage ]; then chown -R www-data:www-data storage bootstrap/cache && chmod -R ug+rwX storage bootstrap/cache; fi"
	@echo "$(GREEN)✓ Права доступа исправлены$(NC)"

info: ## Показать информацию о проекте
	@echo "$(YELLOW)Laravel-Apache-Socket Development Environment$(NC)"
	@echo "======================================"
	@echo "$(GREEN)Сервисы:$(NC)"
	@echo "  • PHP-FPM 8.5 (Alpine)"
	@echo "  • Apache Httpd 2.4 (Alpine)"
	@echo "  • Queue Worker"
	@echo "  • Scheduler (cron)"
	@echo "  • Node.js / Vite HMR (dev only)"
	@echo ""
	@echo "$(GREEN)Внешние сервисы (не в Compose):$(NC)"
	@echo "  • PostgreSQL / MySQL"
	@echo "  • Redis"
	@echo ""
	@echo "$(GREEN)Структура:$(NC)"
	@echo "  • docker/           - Dockerfiles и конфиги сервисов"
	@echo "  • .env              - единый файл настроек (Laravel + Docker)"
	@echo ""
	@echo "$(GREEN)Порты:$(NC)"
	@echo "  • $(HTTPD_PORT) - Apache Httpd (Web Server)"
	@echo "  • 5173 - Vite HMR (dev)"
	@echo "  • Unix Socket - Связь PHP-FPM <-> Apache Httpd"

validate: ## Проверить доступность сервисов по HTTP
	@echo "$(YELLOW)Проверка работы сервисов...$(NC)"
	@echo -n "Apache Httpd (http://localhost:$(HTTPD_PORT)): "
	@curl -s -o /dev/null -w "%{http_code}" http://localhost:$(HTTPD_PORT) && echo " $(GREEN)✓$(NC)" || echo " $(RED)✗$(NC)"
	@echo "$(YELLOW)Статус контейнеров:$(NC)"
	@$(COMPOSE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

clean: ## Удалить контейнеры и тома
	$(COMPOSE) down -v
	@echo "$(RED)! Контейнеры и тома удалены$(NC)"

clean-all: ## Полная очистка (контейнеры, образы, тома)
	@echo "$(YELLOW)Полная очистка...$(NC)"
	$(COMPOSE) down -v --rmi all
	@echo "$(GREEN)✓ Выполнена полная очистка$(NC)"

dev-reset: clean-all build up ## Сброс среды разработки
	@echo "$(GREEN)✓ Среда разработки сброшена и перезапущена!$(NC)"

clean-prod: ## Удалить prod контейнеры и тома
	$(COMPOSE_PROD) down -v
	@echo "$(RED)! Prod контейнеры и тома удалены$(NC)"

clean-all-prod: ## Полная очистка prod (контейнеры, образы, тома)
	@echo "$(YELLOW)Полная очистка prod...$(NC)"
	$(COMPOSE_PROD) down -v --rmi all
	@echo "$(GREEN)✓ Выполнена полная очистка prod$(NC)"

prod-reset: clean-all-prod rebuild-prod up-prod ## Сброс prod среды
	@echo "$(GREEN)✓ Prod среда сброшена и перезапущена!$(NC)"

.DEFAULT_GOAL := help
