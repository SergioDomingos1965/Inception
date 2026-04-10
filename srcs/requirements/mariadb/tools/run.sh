#!/bin/bash
set -e

exec 2>&1  # Redirect stderr to stdout to capture all output

DB_PASSWORD="$(cat /run/secrets/db_password)"
DB_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"

INITIALIZED=0
if [ ! -d "/var/lib/mysql/mysql" ]; then
    INITIALIZED=1
    echo "[INIT] First initialization detected, installing database..."
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
fi

chown -R mysql:mysql /var/lib/mysql
mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld

echo "[INIT] Starting MariaDB in background for setup..."
mariadbd --user=mysql --skip-networking --socket=/tmp/mysql.sock &
PID="$!"

if [ "$INITIALIZED" -eq 1 ]; then
    PING_CMD=(mariadb-admin --socket=/tmp/mysql.sock -uroot)
    SQL_PASS=""
    echo "[INIT] Using password-less root (first init)"
else
    PING_CMD=(mariadb-admin --socket=/tmp/mysql.sock -uroot -p"${DB_ROOT_PASSWORD}")
    SQL_PASS="-p${DB_ROOT_PASSWORD}"
    echo "[INIT] Using root password (existing database)"
fi

echo "[INIT] Waiting for MariaDB to be ready..."
for i in $(seq 1 30); do
    if "${PING_CMD[@]}" ping >/dev/null 2>&1; then
        echo "[INIT] MariaDB is ready!"
        break
    fi
    sleep 1
done

# Always ensure database and user are properly configured
echo "[INIT] Configuring database and user..."
if mariadb --socket=/tmp/mysql.sock -uroot $SQL_PASS <<EOF
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
FLUSH PRIVILEGES;
EOF
then
    echo "[INIT] Database configured successfully"
else
    echo "[INIT] ERROR: Failed to configure database"
fi

if [ "$INITIALIZED" -eq 1 ]; then
    echo "[INIT] Setting root password (first init)..."
    mariadb --socket=/tmp/mysql.sock -uroot <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
EOF
fi

echo "[INIT] Shutting down MariaDB for restart..."
mariadb-admin --socket=/tmp/mysql.sock -uroot -p"${DB_ROOT_PASSWORD}" shutdown
wait "$PID" || true

echo "[INIT] Starting MariaDB daemon..."
exec mariadbd --user=mysql --bind-address=0.0.0.0
