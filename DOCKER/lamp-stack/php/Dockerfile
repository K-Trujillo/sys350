FROM php:8.2-apache

# Install PHP extensions for MySQL connectivity
RUN docker-php-ext-install pdo_mysql mysqli

# Copy application code into the web root
COPY src/ /var/www/html/

# Set correct ownership for Apache
RUN chown -R www-data:www-data /var/www/html
