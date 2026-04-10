#!/bin/bash
set -e

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_EDITOR_PASSWORD="$(cat /run/secrets/wp_editor_password)"

echo "Waiting for MySQL server at ${DB_HOST} to be available..."

CONNECTED=0
for i in $(seq 1 60); do
    if mariadb-admin ping -h"${DB_HOST}" -u"${MYSQL_USER}" -p"${DB_PASSWORD}" --silent; then
        CONNECTED=1
        break
    fi
    sleep 1
done

if [ "$CONNECTED" -ne 1 ]; then
    echo "ERROR: Failed to connect to MySQL server at ${DB_HOST} after 60 seconds"
    exit 1
fi

echo "Connected to MySQL server at ${DB_HOST}"

cd /var/www/html

if [ ! -f wp-config.php ]; then
    echo "Setting up WordPress..."
    # Remove incomplete WordPress installation
    rm -f index.* license.txt readme.html *.php
    rm -rf wp-* 2>/dev/null || true

    wp core download --allow-root

    echo "Creating wp-config.php..."
    echo "variaveis: ${MYSQL_DATABASE} ${MYSQL_USER} ${DB_PASSWORD} ${DB_HOST}"
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="${DB_HOST}" \
        --allow-root

    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --allow-root

    wp user create "${WP_EDITOR_USER}" "${WP_EDITOR_EMAIL}" \
        --role=editor \
        --user_pass="${WP_EDITOR_PASSWORD}" \
        --allow-root
fi

exec php-fpm8.2 -F
