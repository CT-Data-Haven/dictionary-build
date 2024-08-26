#!/usr/bin/env bash
META=$1
DB=$2
FLAG=$3

# read version from toml
version=$(tomlq -r "$META" .version)
tag="v$version"

# is there already a release called viz? if not, create it
if ! gh release view "$tag" >/dev/null 2>&1; then
    gh release create "$tag" --title "duckdb database" --notes ""
fi

gh release upload "$tag" \
    "$DB" \
    --clobber

gh release view "$tag" \
    --json id,tagName,assets,createdAt,url > \
    "$FLAG"
