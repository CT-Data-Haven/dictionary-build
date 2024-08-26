#!/usr/bin/env bash
DB=$1
KEY=$2
CON="md:?motherduck_token=${KEY}"
# doesn't work well if all done in one line...?
# duckdb -c "show all databases;" "$CON"
duckdb -c "attach '${DB}';" "$CON"
duckdb -c "create or replace database glossary from '${DB}';" "$CON"
duckdb -c "select * from information_schema.tables where table_schema = 'main';" "$CON"
# duckdb -c "select * from glossary.variables limit 5;" "$CON"
duckdb -noheader -list -c "SELECT strftime(current_timestamp, '%Y-%m-%dT%H:%M:%S.000Z');" > .last_upload