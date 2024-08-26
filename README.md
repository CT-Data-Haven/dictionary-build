# data dictionary


First attempt at a basic data dictionary for indicators used at
DataHaven. Edits are done in Airtable, then loaded into a duckdb
database (`gloss.duckdb`). This database is also made available in
tagged releases in this repo and on the Motherduck platform (contact
Camille if you want access). The release should facilitate building an R
package to query sets of definitions easily, e.g. all indicators used in
a specific project, or all indicators associated with a certain source.

The tables in the database are:

    ┌────────────┬───────┬─────────┐
    │ table_name │ rows  │ columns │
    │  varchar   │ int64 │  int64  │
    ├────────────┼───────┼─────────┤
    │ projects   │     3 │       3 │
    │ sources    │    12 │       7 │
    │ variables  │    85 │      10 │
    │ vocab      │     1 │       6 │
    └────────────┴───────┴─────────┘

Workflows are managed with snakemake, as shown:

    Building DAG of jobs...

![dag](./dag.png)
