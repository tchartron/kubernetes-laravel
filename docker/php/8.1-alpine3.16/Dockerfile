# Laravel required extensions here: https://laravel.com/docs/9.x/deployment#server-requirements
ARG PHP_BUILD_DEPS="bash coreutils ca-certificates libtool openssl curl-dev freetype-dev icu-dev libjpeg-turbo-dev libpng-dev libwebp-dev libzip-dev libsodium-dev zlib-dev libxml2-dev libssh-dev oniguruma-dev lz4-dev"
ARG PHP_RUNTIME_DEPS="libpng libjpeg-turbo freetype icu lz4-libs libzip"
# ARG PHP_EXTS="bcmath ctype fileinfo mbstring pdo pdo_mysql tokenizer dom pcntl"
ARG PHP_EXTS="exif gd curl intl zip pdo pdo_mysql bcmath mbstring opcache"
ARG LARAVEL_ROOT="./laravel-app"
# Already bundled in php 8.1 see https://www.php.net/manual/en/extensions.alphabetical.php
# ctype pcntl fileinfo tokenizer xml # json simplexml sockets
# ARG PHP_PECL_EXTS="redis" # not used because using redis with msgpack serialization and lz4 compression

##################################################
#####                                         ####
#                BACKEND_SOURCES                 #
####                                          ####
##################################################
FROM php:8.1-cli-alpine3.16 as backend_sources

# ARG PHP_EXTS
# ARG PHP_BUILD_DEPS
ARG LARAVEL_ROOT

RUN mkdir -p /var/www/kubernetes-laravel /var/www/kubernetes-laravel/bin

WORKDIR /var/www/kubernetes-laravel

# if the redis php extension is not installed, config/database.php Redis::SERIALIZER_MSGPACK fails when generating autoloader
RUN apk add --virtual build-dependencies --no-cache ${PHPIZE_DEPS} lz4-dev \
    && pecl install msgpack \
    && mkdir -p /tmp/pear \
    && cd /tmp/pear \
    && pecl bundle redis \
    && cd redis \
    && phpize \
    && ./configure --enable-redis-msgpack --enable-redis-lz4 --with-liblz4=/usr \
    && make && make install \
    && docker-php-ext-enable msgpack \
    && docker-php-ext-enable redis \
    && cd - && rm -rf /tmp/pear

# Composer latest (2.3 at the time)
COPY --from=composer:2.3 /usr/bin/composer /usr/local/bin/composer
RUN chmod +x /usr/local/bin/composer

RUN addgroup -S composer \
    && adduser -S composer -G composer \
    && chown -R composer /var/www/kubernetes-laravel

# Switch over to the composer user before running installs (isolated from root filesystem)
USER composer

# Copy in our dependency files.
# so Docker can build a cache of this layer,
COPY --chown=composer $LARAVEL_ROOT/composer.json $LARAVEL_ROOT/composer.lock ./

# Install all the dependencies without running any installation scripts.
# As long as composer.json and composer.lock doesn't change the install will be cached.
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

COPY --chown=composer $LARAVEL_ROOT .

# run the install again, and let it run any install scripts.
RUN composer install --optimize-autoloader --no-dev --prefer-dist

USER root
RUN apk del build-dependencies
USER composer

##################################################
#####                                         ####
#                   PHP CLI                      #
####        migrations, queue workers         ####
##################################################
FROM php:8.1-cli-alpine3.16 as cli

LABEL maintainer="Thomas Chartron <thomas.chartron@gmail.com>"

ARG PHP_EXTS
ARG PHP_BUILD_DEPS
ARG PHP_RUNTIME_DEPS

WORKDIR /var/www/kubernetes-laravel

# naming the virtual package build-dependencies prevents docker-php-ext-enable or docker-php-ext-install from removing PHPIZE_DEPS !
RUN apk add --virtual build-dependencies --no-cache ${PHPIZE_DEPS} ${PHP_BUILD_DEPS} \
    # PHP extensions configure
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure zip \
    && docker-php-ext-install -j$(nproc) ${PHP_EXTS} \
    # && pecl install ${PHP_PECL_EXTS} \
    # && docker-php-ext-enable ${PHP_PECL_EXTS} \
    # Redis pecl extensions with msgpack serialization and lz4 compression
    && pecl install msgpack \
    && mkdir -p /tmp/pear \
    && cd /tmp/pear \
    && pecl bundle redis \
    && cd redis \
    && phpize \
    && ./configure --enable-redis-msgpack --enable-redis-lz4 --with-liblz4=/usr \
    && make && make install \
    && docker-php-ext-enable msgpack \
    && docker-php-ext-enable redis \
    && cd - && rm -rf /tmp/pear \
    && apk del build-dependencies

# Install runtime dependencies
RUN apk add --no-cache ${PHP_RUNTIME_DEPS}

### PHP configurations
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# Cleanup
RUN rm -rf /tmp/*

COPY --from=backend_sources /var/www/kubernetes-laravel /var/www/kubernetes-laravel


##################################################
#####                                         ####
#                     CRON                       #
####                scheduler                 ####
##################################################
# override the CMD which the container starts with to point at cron
FROM cli as cron

LABEL maintainer="Thomas Chartron <thomas.chartron@gmail.com>"

WORKDIR /var/www/kubernetes-laravel

# Create a laravel.cron file with Laravel cron settings, which we can import into crontab,
# and run crond as the primary command in the foreground
RUN touch laravel.cron && \
    echo "* * * * * cd /var/www/kubernetes-laravel && php artisan schedule:run" >> laravel.cron && \
    crontab laravel.cron

CMD ["crond", "-l", "2", "-f"]

##################################################
#####                                         ####
#                   PHP FPM                      #
####                                          ####
##################################################
# Source : https://github.com/docker-library/php/blob/master/8.1/alpine3.16/fpm/Dockerfile
FROM php:8.1-fpm-alpine3.16 as fpm

LABEL maintainer="Thomas Chartron <thomas.chartron@gmail.com>"

ARG PHP_EXTS
ARG PHP_BUILD_DEPS
ARG PHP_RUNTIME_DEPS

ENV OPCACHE_ENABLE="1" \
    OPCACHE_REVALIDATE_FREQ="120" \
    OPCACHE_VALIDATE_TIMESTAMPS="1" \
    OPCACHE_MAX_ACCELERATED_FILES="10000" \
    OPCACHE_MEMORY_CONSUMPTION="256" \
    OPCACHE_MAX_WASTED_PERCENTAGE="10" \
    OPCACHE_INTERNED_STRINGS_BUFFER="32" \
    OPCACHE_JIT="tracing" \
    OPCACHE_JIT_BUFFER_SIZE="256M" \
    OPCACHE_JIT_DEBUG="0"

WORKDIR /var/www/kubernetes-laravel

# naming the virtual package build-dependencies prevents docker-php-ext-enable or docker-php-ext-install from removing PHPIZE_DEPS !
RUN apk add --virtual build-dependencies --no-cache ${PHPIZE_DEPS} ${PHP_BUILD_DEPS} \
    # PHP extensions configure
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure zip \
    && docker-php-ext-install -j$(nproc) ${PHP_EXTS} \
    # && pecl install ${PHP_PECL_EXTS} \
    # && docker-php-ext-enable ${PHP_PECL_EXTS} \
    # Redis pecl extensions with msgpack serialization and lz4 compression
    && pecl install msgpack \
    && mkdir -p /tmp/pear \
    && cd /tmp/pear \
    && pecl bundle redis \
    && cd redis \
    && phpize \
    && ./configure --enable-redis-msgpack --enable-redis-lz4 --with-liblz4=/usr \
    && make && make install \
    && docker-php-ext-enable msgpack \
    && docker-php-ext-enable redis \
    && cd - && rm -rf /tmp/pear \
    && apk del build-dependencies

# Install runtime dependencies
RUN apk add --no-cache ${PHP_RUNTIME_DEPS}

######################
### PHP configurations
######################
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
# RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"
# Opcache
COPY docker/php/8.1-alpine3.16/conf/opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Cleanup
RUN rm -rf /tmp/*

# FPM uses the www-data user when running our application,
# we need to make sure that we also use that user when starting up,
# so our user "owns" the application when running
USER www-data

COPY --from=backend_sources --chown=www-data /var/www/kubernetes-laravel /var/www/kubernetes-laravel

# Laravel cache command for production
RUN php artisan config:cache
RUN php artisan route:cache
RUN php artisan view:cache
RUN php artisan event:cache

