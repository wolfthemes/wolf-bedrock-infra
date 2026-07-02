# Same image for local dev and deployment. In dev, docker-compose bind-mounts
# the project root over the COPY'd code below so edits are live. In CI, no
# bind-mount — this image is the immutable, self-contained deploy artifact.

FROM php:8.3-fpm

RUN apt-get update && apt-get install -y --no-install-recommends \
      git unzip libzip-dev \
    && docker-php-ext-install mysqli zip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY config/php.ini /usr/local/etc/php/conf.d/custom.ini

WORKDIR /var/www/html
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-scripts

# web/app/themes/* and web/app/plugins/* submodules, already built by their
# own CI (npm run build) and checked out at their pinned commit.
COPY . .
