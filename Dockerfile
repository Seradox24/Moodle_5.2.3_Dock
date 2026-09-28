ARG DEBIAN_IMAGE
ARG PHP_IMAGE
ARG NGINX_IMAGE

FROM ${DEBIAN_IMAGE} AS moodle-source

ARG MOODLE_VERSION
ARG MOODLE_GIT_TAG
ARG MOODLE_GIT_REF
ARG LAUNCHER_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

RUN test "${MOODLE_GIT_TAG#v}" = "${MOODLE_VERSION}" \
    && git init /src \
    && cd /src \
    && git remote add origin https://github.com/moodle/moodle.git \
    && git fetch --depth 1 origin "refs/tags/${MOODLE_GIT_TAG}:refs/tags/${MOODLE_GIT_TAG}" \
    && git checkout --detach "${MOODLE_GIT_TAG}" \
    && test "$(git rev-parse HEAD)" = "${MOODLE_GIT_REF}" \
    && printf '%s\n' "${MOODLE_GIT_REF}" > /src/.build-ref \
    && printf '%s\n' "${MOODLE_VERSION}" > /src/.build-version \
    && printf '%s\n' "${LAUNCHER_VERSION}" > /src/.launcher-version \
    && rm -rf /src/.git \
    && mv /src/public /moodle-public

FROM ${PHP_IMAGE} AS app

ARG LAUNCHER_VERSION
ARG MOODLE_VERSION
ARG MOODLE_GIT_REF
ARG RELEASE_IMAGE_TAG

LABEL org.opencontainers.image.version="${RELEASE_IMAGE_TAG}" \
      org.opencontainers.image.revision="${MOODLE_GIT_REF}" \
      io.lms.launcher.version="${LAUNCHER_VERSION}" \
      io.lms.moodle.version="${MOODLE_VERSION}"

RUN test "${RELEASE_IMAGE_TAG}" = "moodle-${MOODLE_VERSION}-launcher-${LAUNCHER_VERSION}"

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
COPY docker/php/generate-limits.sh /usr/local/bin/generate-limits.sh

RUN chmod 0755 /usr/local/bin/moodle-cron-loop.sh \
    && chmod 0755 /usr/local/bin/init-code.sh /usr/local/bin/moodle-entrypoint.sh /usr/local/bin/generate-limits.sh \
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

ARG LAUNCHER_VERSION
ARG MOODLE_VERSION
ARG MOODLE_GIT_REF
ARG RELEASE_IMAGE_TAG

ENV NGINX_ENVSUBST_OUTPUT_DIR=/tmp/nginx-conf.d \
    MOODLE_MAX_REQUEST_MB=300 \
    MOODLE_FASTCGI_READ_TIMEOUT_SECONDS=120

LABEL org.opencontainers.image.version="${RELEASE_IMAGE_TAG}" \
      org.opencontainers.image.revision="${MOODLE_GIT_REF}" \
      io.lms.launcher.version="${LAUNCHER_VERSION}" \
      io.lms.moodle.version="${MOODLE_VERSION}"

COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY docker/nginx/limits.conf.template /etc/nginx/templates/limits.conf.template

# Match the PHP www-data GID so Nginx can read plugin assets created with 0770.
# The shared code volume is mounted read-only in this service.
RUN addgroup -S -g 33 moodle-code \
    && test "${RELEASE_IMAGE_TAG}" = "moodle-${MOODLE_VERSION}-launcher-${LAUNCHER_VERSION}" \
    && addgroup nginx moodle-code \
    && mkdir -p /var/www/moodle/public
