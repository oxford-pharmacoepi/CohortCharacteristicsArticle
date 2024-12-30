
omopgenerics::importCodelist(path = here::here("Codelists"), type = "csv") |>
  purrr::imap(\(x, nm) dplyr::tibble(codelist_name = nm, concept_id = x)) |>
  dplyr::bind_rows() |>
  dplyr::left_join(
    cdm$concept |>
      dplyr::select(
        "concept_id", "concept_name", "domain_id", "vocabulary_id", 
        "standard_concept"
      ) |>
      dplyr::collect(), 
    by = "concept_id"
  ) |>
  readr::write_csv(file = here::here("codelists_definitions.csv"))
