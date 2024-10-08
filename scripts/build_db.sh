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

# write timestamp
# date -u +"%Y-%m-%dT%H:%M:%S.000Z" > .last_build
duckdb -noheader -list -c "SELECT strftime(current_timestamp, '%Y-%m-%dT%H:%M:%S.000Z');" > .last_build