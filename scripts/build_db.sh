#!/usr/bin/env bash
# assign first argument to DB, remaining to FILES
DB="$1"
shift
FILES=("$@")

# copy to db
for file in "${FILES[@]}"; do
    tbl=$(basename "$file" .json)
    duckdb -c "DROP TABLE IF EXISTS $tbl;" "$DB"
    duckdb -c "CREATE TABLE $tbl AS 
        SELECT *
        FROM read_json('$file', auto_detect = true);" "$DB"
done

# check tables
duckdb -c "SELECT table_name, count(*) AS columns
    FROM information_schema.columns
    WHERE table_schema = 'main'
    GROUP BY table_name;" "$DB"

# make array of table names
mapfile -t tbls < <(duckdb -noheader -list -c "SELECT DISTINCT table_name
    FROM information_schema.tables
    WHERE table_schema = 'main';" "$DB")

for tbl in "${tbls[@]}"; do
    duckdb -c "WITH info AS (
        SELECT '${tbl}' AS table_name, *
        FROM ${tbl}
    )
    SELECT table_name, count(table_name) AS nrow
    FROM info 
    GROUP BY table_name;" "$DB"
done

# write timestamp
date -u +"%Y-%m-%dT%H:%M:%S.000Z" > .last_build