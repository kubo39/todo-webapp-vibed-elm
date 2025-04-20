#!/bin/bash

set -e

psql  -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
CREATE TABLE task (
    id SERIAL PRIMARY KEY,
    text TEXT,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP
);
EOSQL
