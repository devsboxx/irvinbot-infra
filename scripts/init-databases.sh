#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
  SELECT 'CREATE DATABASE irvinbot_auth'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'irvinbot_auth')\gexec
  SELECT 'CREATE DATABASE irvinbot_chat'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'irvinbot_chat')\gexec
  SELECT 'CREATE DATABASE irvinbot_docs'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'irvinbot_docs')\gexec
EOSQL

echo "Databases irvinbot_auth, irvinbot_chat, irvinbot_docs ready."
