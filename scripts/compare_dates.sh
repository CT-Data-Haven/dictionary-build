#!/usr/bin/env bash
# airtable last modified date is in github issue #1.
# last build date is in flag file. 
# return 1 (update) if airtable date is later than flag file date, 0 (don't update) otherwise.
# if no date flag exists, return 1.
flagin=$1
flagout=$2
need_update=1
airtable=$(gh issue view 1 --json body --jq '.body')

# if flagfile exists, compare dates
if [ -f "$flagin" ]; then
    flag=$(cat "$flagin")
    if [[ "$airtable" < "$flag" ]]; then
        need_update=0
    fi
fi

# if need_update = 1, touch flagfile
if [ $need_update -eq 1 ]; then
    touch "$flagout"
fi