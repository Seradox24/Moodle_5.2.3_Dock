ARG PHP_IMAGE=php:8.3-fpm-bookworm
ARG NGINX_IMAGE=nginx:1.28-alpine

FROM debian:bookworm-slim AS moodle-source

ARG MOODLE_GIT_TAG=v5.2.3
ARG MOODLE_GIT_REF=344232c15336c71b80f9aca8359ce0e0a9f3d116

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

RUN git init /src \
    && cd /src \
    && git remote add origin https://github.com/moodle/moodle.git \
    && git fetch --depth 1 origin "refs/tags/${MOODLE_GIT_TAG}:refs/tags/${MOODLE_GIT_TAG}" \
    && git checkout --detach "${MOODLE_GIT_TAG}" \
    && test "$(git rev-parse HEAD)" = "${MOODLE_GIT_REF}" \
    && printf '%s\n' "${MOODLE_GIT_REF}" > /src/.build-ref \
    && rm -rf /src/.git \
    && mv /src/public /moodle-public

FROM ${PHP_IMAGE} AS app

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        libfreetype6-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libldap2-dev \
        libonig-dev \
        libpng-dev \
        libpq-dev \
        libxml2-dev \
        libxslt1-dev \
        libzip-dev \
        unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        calendar \
        exif \
        gd \
        gettext \
        intl \
        ldap \
        mbstring \
        opcache \
        pcntl \
        pdo_pgsql \
        pgsql \
        soap \
        sockets \
        xsl \
        zip \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /tmp/pear /var/lib/apt/lists/*

COPY --from=moodle-source /src /var/www/moodle
COPY --from=moodle-source /moodle-public /opt/moodle-public
COPY config/config.php /var/www/moodle/config.php
COPY docker/php/moodle.ini /usr/local/etc/php/conf.d/zz-moodle.ini
COPY docker/php/www.conf /usr/local/etc/php-fpm.d/zz-moodle.conf
COPY docker/cron/moodle-cron-loop.sh /usr/local/bin/moodle-cron-loop.sh
COPY docker/install/init-code.sh /usr/local/bin/init-code.sh
COPY docker/install/moodle-entrypoint.sh /usr/local/bin/moodle-entrypoint.sh

RUN chmod 0755 /usr/local/bin/moodle-cron-loop.sh \
    && chmod 0755 /usr/local/bin/init-code.sh /usr/local/bin/moodle-entrypoint.sh \
    && mkdir -p /var/moodledata /var/www/moodle/public \
    && chown -R root:root /var/www/moodle \
    && chmod -R a-w /var/www/moodle \
    && chown -R www-data:www-data /var/moodledata \
    && chmod 0770 /var/moodledata

COPY docker/install/install-database.sh /usr/local/bin/install-database.sh
COPY docker/install/check-runtime.php /usr/local/bin/check-runtime.php

WORKDIR /var/www/moodle
ENTRYPOINT ["/usr/local/bin/moodle-entrypoint.sh"]
CMD ["php-fpm"]

FROM ${NGINX_IMAGE} AS web

COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf

# Match the PHP www-data GID so Nginx can read plugin assets created with 0770.
# The shared code volume is mounted read-only in this service.
RUN addgroup -S -g 33 moodle-code \
    && addgroup nginx moodle-code \
    && mkdir -p /var/www/moodle/public
