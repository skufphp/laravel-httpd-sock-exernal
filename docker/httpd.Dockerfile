# ==============================================================================
# Многоэтапный образ Apache Httpd (Unix Socket) — Alpine (Laravel)
# ==============================================================================
# Назначение:
# - Development: только Httpd-конфиг, код монтируется volume'ом
# - Production: самодостаточный immutable-образ с public/ и build-ассетами
#
# Stages:
#   frontend-build  — сборка Vite-ассетов
#   httpd-base      — общая база Apache Httpd
#   development     — dev-образ без копирования кода приложения
#   production      — prod-образ с public/ внутри контейнера
# ==============================================================================

FROM node:24-alpine AS frontend-build

WORKDIR /app

# Устанавливаем frontend-зависимости отдельным слоем для лучшего кеширования
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci; else npm install; fi

# Копируем проект и собираем production-ассеты
COPY . ./
RUN npm run build


# ==============================================================================
# Базовый образ Apache Httpd
# ==============================================================================
FROM httpd:2.4-alpine AS httpd-base

# Добавляем пользователя Apache (daemon) в группу www-data,
# чтобы Apache мог читать/писать в UNIX-сокет PHP-FPM
RUN addgroup daemon www-data

WORKDIR /var/www/laravel

# Вшиваем конфиг виртуального хоста в образ
COPY docker/httpd/conf/httpd.conf /usr/local/apache2/conf/httpd.conf

# Подготавливаем директории, которые используются Apache и приложением
RUN set -eux; \
    mkdir -p \
      /var/www/laravel/public


# ==============================================================================
# Development образ
# ==============================================================================
FROM httpd-base AS development

# В development код приложения приходит через bind mount:
#   .:/var/www/laravel
# Поэтому ничего из проекта в образ не копируем.
CMD ["httpd-foreground"]


# ==============================================================================
# Production образ
# ==============================================================================
FROM httpd-base AS production

WORKDIR /var/www/laravel

# Копируем только публичную часть приложения.
# Apache не нужен весь Laravel-проект — только public/.
COPY public ./public

# Удаляем маркер dev-сервера Vite, если он случайно попал в контекст
RUN rm -f /var/www/laravel/public/hot

# Подкладываем production-ассеты поверх public/
COPY --from=frontend-build /app/public/build /var/www/laravel/public/build

# Финальные безопасные права на чтение публичных файлов
RUN set -eux; \
    chown -R daemon:www-data /var/www/laravel/public; \
    find /var/www/laravel/public -type d -exec chmod 755 {} \;; \
    find /var/www/laravel/public -type f -exec chmod 644 {} \;

CMD ["httpd-foreground"]
