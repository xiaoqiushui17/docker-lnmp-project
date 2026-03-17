FROM php:7.4-fpm
RUN docker-php-ext-install mysqli
COPY html /var/www/html
