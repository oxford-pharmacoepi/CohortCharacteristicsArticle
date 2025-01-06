# shiny is prepared to work with this resultList, please do not change them
resultList <- list(
  "summarise_omop_snapshot" = c(1L),
  "summarise_cohort_count" = c(2L),
  "summarise_cohort_attrition" = c(3L, 4L, 5L, 6L, 7L),
  "summarise_cohort_overlap" = c(8L),
  "summarise_cohort_timing" = c(9L),
  "summarise_characteristics" = c(10L),
  "summarise_large_scale_characteristics" = c(11L, 12L)
)

source(file.path(getwd(), "functions.R"))

result <- omopgenerics::importSummarisedResult(file.path(getwd(), "data"))

# correct any_antipsychotics
result <- result |>
  dplyr::mutate(group_level = stringr::str_replace_all(
    .data$group_level, "any_antipsychotic", "any_antipsychotics"
  ))

data <- prepareResult(result, resultList)
filterValues <- defaultFilterValues(result, resultList)

# cohort definitions
cohortDefinitions <- readr::read_csv(
  file = file.path(getwd(), "data", "cohort_definitions.csv"), 
  col_types = c(.default = "c"), 
  show_col_types = FALSE
)

# codelist definitions
codelistDefinitions <- readr::read_csv(
  file = file.path(getwd(), "data", "codelists_definitions.csv"), 
  col_types = c(.default = "c", concept_id = "i"), 
  show_col_types = FALSE
) |>
  dplyr::mutate(concept_name = paste0(
    "<a href='https://athena.ohdsi.org/search-terms/terms/", .data$concept_id, 
    "'>", .data$concept_name, "</a>"
  )) |>
  dplyr::group_by(.data$codelist_name) |>
  dplyr::group_split() |>
  as.list()
names(codelistDefinitions) <- codelistDefinitions |>
  purrr::map(\(x) x$codelist_name |> unique())
codelistDefinitions <- codelistDefinitions |>
  purrr::map(\(x) dplyr::select(x, -"codelist_name"))

# codelists used in cohorts
cohortDefinitions <- cohortDefinitions |>
  dplyr::mutate(
    codelist_name = stringr::str_extract_all(.data$value, "`(.*?)`") |>
      purrr::map(\(x) substr(x, 2, nchar(x)-1))
  )

cohortNames <- unique(cohortDefinitions$cohort_name)
cdmNames <- unique(result$cdm_name)

save(
  data, filterValues, cohortDefinitions, codelistDefinitions, cohortNames,
  cdmNames, file = file.path(getwd(), "data", "shinyData.RData")
)

rm(result, filterValues, resultList, data, cohortDefinitions, codelistDefinitions, cohortNames, cdmNames)
