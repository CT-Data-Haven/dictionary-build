library(dplyr)
if (exists("snakemake")) {
    key <- snakemake@params[["key"]]
} else {
    readRenviron(".env")
    key <- Sys.getenv("AIRTABLE_API_KEY")
}

# get dictionary base ID--otherwise just annoying to have to hardcode
id_resp <- httr2::request("https://api.airtable.com/v0/meta/bases") |>
    httr2::req_auth_bearer_token(key) |>
    httr2::req_perform() |>
    httr2::resp_body_json() |>
    purrr::pluck("bases")
id <- id_resp[purrr::map_lgl(id_resp, \(x) x$name == "Dictionary")][[1]]$id

# get names of all tables in base
tbl_names <- httr2::request(sprintf("https://api.airtable.com/v0/meta/bases/%s/tables", id)) |>
    httr2::req_auth_bearer_token(key) |>
    httr2::req_perform() |>
    httr2::resp_body_json() |>
    purrr::pluck("tables") |>
    purrr::map_chr("name") |>
    rlang::set_names()
tbls <- tbl_names |>
    purrr::map(\(x) rairtable::airtable(x, id)) |>
    purrr::map(rairtable::read_airtable) |>
    purrr::map(as_tibble)

clean_tbls <- out <- list()
clean_tbls[["variables"]] <- tbls[["variables"]] |>
    tidyr::unnest(universe, keep_empty = TRUE) |>
    tidyr::unnest(dataset, keep_empty = TRUE) |>
    select(
        variable_id = airtable_record_id, 
        variable,
        display,
        dataset_id = dataset,
        project_id = project,
        universe_id = universe,
        everything()
    )
clean_tbls[["sources"]] <- tbls[["sources"]] |>
    select(
        dataset_id = airtable_record_id,
        dataset,
        everything(),
        -variables
    )
clean_tbls[["projects"]] <- tbls[["projects"]] |>
    select(
        project_id = airtable_record_id,
        project, 
        repo
    )
clean_tbls[["vocab"]] <- tbls[["vocab"]] |>
    select(
        term_id = airtable_record_id,
        term,
        project_id = project,
        everything()
    )

ids <- clean_tbls |>
    purrr::map(select, 1:2)

# join text fields back on by IDs
out[["variables"]] <- clean_tbls[["variables"]] |>
    tidyr::unnest(project_id) |>
    left_join(
        ids[["variables"]] |>
            rename(universe = variable, universe_id = variable_id),
        by = "universe_id"
    ) |>
    left_join(ids[["sources"]], by = "dataset_id") |>
    left_join(ids[["projects"]], by = "project_id") |>
    select(variable_id, variable, display, dataset, universe, measure_type, question, detail, var_order, project) |>
    group_by(across(-project)) |>
    # nest back
    summarise(project = list(project)) |>
    ungroup() |>
    arrange(var_order)

out[["sources"]] <- clean_tbls[["sources"]] |>
    select(dataset_id, dataset, org, program, everything())

out[["projects"]] <- clean_tbls[["projects"]]

out[["vocab"]] <- clean_tbls[["vocab"]] |>
    tidyr::unnest(project_id) |>
    left_join(ids[["projects"]], by = "project_id") |>
    select(-project_id) |>
    group_by(across(-project)) |>
    summarise(project = list(project)) |>
    ungroup() |>
    arrange(term_order)

purrr::iwalk(out, function(df, id) {
    path <- file.path("input_data", paste(id, "json", sep = "."))
    jsonlite::write_json(df, path)
})