# get json with format
# vars:
# -- source1:
# -- variables1:
# ---- indicator:
# ---- detail:
# vocab:
# -- term1:

# need:
# * variables containing town_viewer in project
# * sources corresponding to those variables
# * vocab containing town_viewer in project
library(dplyr)

con <- DBI::dbConnect(duckdb::duckdb("gloss.duckdb", read_only = TRUE))

# filter variables for this project, join sources
# get just the first row for each set of details, such that
# e.g. Latino population, percent Latino won't both appear
DBI::dbExecute(
    con,
    "
    create or replace temporary view town_viewer as (
        with vrs as (
            select variable, display, dataset, coalesce(question, detail) as detail, var_order
            from variables
            where list_contains(project, 'town_viewer')
            order by var_order
        ),
        src as (
            select 
                replace(org, 'DataHaven', 'Questions on the') as org, 
                program, 
                dataset
            from sources
        )
        select
            vrs.variable,
            vrs.display,
            vrs.dataset,
            vrs.detail,
            vrs.var_order,
            concat_ws(' ', src.org, src.program) as source
        from vrs
        inner join src
        on vrs.dataset = src.dataset
    );
    "
)

proj <- DBI::dbGetQuery(
    con,
    "
    with proj_defs as (
        select *,
            row_number() over (partition by detail order by var_order) as row
        from town_viewer
        where detail is not null
    ),
    proj_vocab as (
        select
            term,
            definition,
            'General terms' as source,
            url
        from vocab
        where list_contains(project, 'town_viewer')
        order by term_order
    ),
    proj_vars as (
        select 
            display as term, 
            detail as definition, 
            source,
            null as url
        from proj_defs
        where row = 1
        order by var_order
    )
    select * from proj_vocab
    union all by name
    select * from proj_vars
    ;
    "
)

defs <- proj |>
    as_tibble() |>
    mutate(source = forcats::as_factor(source)) |>
    group_by(source) |>
    tidyr::nest(.key = "variables")

jsonlite::write_json(defs, "output_data/dictionary.json")

DBI::dbDisconnect(con)