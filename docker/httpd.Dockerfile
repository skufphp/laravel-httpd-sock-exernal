# ==============================================================================
# Dockerfile для Apache (Httpd)
# Базовый образ: Apache на Alpine Linux (минималистичный и производительный)
# ==============================================================================
FROM httpd:alpine

# Добавляем пользователя Apache (daemon) в группу www-data
# Это необходимо для того, чтобы Apache мог читать/писать в UNIX-сокет,
# владельцем которого является пользователь www-data (из PHP-FPM)
RUN addgroup daemon www-data

# Рабочая директория (соответствует PHP-контейнеру)
WORKDIR /var/www/laravel

# Вшиваем конфиг виртуального хоста в образ (prod-friendly).
# В dev при желании можно будет переопределить volume-ом.
COPY ./httpd/conf/httpd.conf /usr/local/apache2/conf/httpd.conf