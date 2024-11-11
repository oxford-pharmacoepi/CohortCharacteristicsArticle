info(logger = logger, "LOAD IN CODELIST")

drug_all <- readr::read_csv(here("Cohorts", "drug_all_codelist.csv"))
drug_code_route <-
  readr::read_csv(here("Cohorts", "drug_route_codelist.csv"))

#convert tibble to list
drug_all <- drug_all |> dplyr::group_by(name) |> 
  dplyr::summarise(concept_id = list(concept_id), .groups = "drop") |>
  tibble::deframe()

drug_code_route <- drug_code_route |> dplyr::group_by(name) |> 
  dplyr::summarise(concept_id = list(concept_id), .groups = "drop") |>
  tibble::deframe()

info(logger = logger, "CREATE DRUG COHORT")
# all
cdm <-
  cdm |> generateDrugUtilisationCohortSet(name = drug_cohort_name,
                                          conceptSet = drug_all,
                                          gapEra = 30)
#restrict to new user
cdm[[drug_cohort_name]] <- cdm[[drug_cohort_name]] |>
  requireIsFirstDrugEntry() |> requireObservationBeforeDrug(days = 365) |>
  requireDrugInDateRange(
    dateRange = c(studyStartDate, studyEndDate),
    indexDate = "cohort_start_date",
    cohortId = NULL
  )
# route
cdm <-
  cdm |> generateDrugUtilisationCohortSet(name = drug_route_cohort,
                                          conceptSet = drug_code_route,
                                          gapEra = 30)

#restrict to new user
cdm[[drug_route_cohort]] <- cdm[[drug_route_cohort]] |>
  requireIsFirstDrugEntry() |> requireObservationBeforeDrug(days = 365) |>
  requireDrugInDateRange(
    dateRange = c(studyStartDate, studyEndDate),
    indexDate = "cohort_start_date",
    cohortId = NULL
  )

##bind cohort for attrition
drug_attrition <-
  omopgenerics::bind(CohortCharacteristics::summariseCohortAttrition(cdm[[drug_cohort_name]]), 
                     CohortCharacteristics::summariseCohortAttrition(cdm[[drug_route_cohort]]))

##indications cohort
info(logger = logger, "INDICATION COHORT CREATION")

cohort_json_dir <- here("Cohorts", "indication")
cohort_set <- read_cohort_set(cohort_json_dir)

cdm <- generateCohortSet(
  cdm,
  cohort_set,
  name = ind_cohort,
  computeAttrition = TRUE,
  overwrite = TRUE
)

info(logger, "Getting index event breakdown")

results <- list()


cdm <-
  omopgenerics::bind(cdm[[drug_cohort_name]], cdm[[drug_route_cohort]], name = "alldrugs")


cohortIdsWithCount <- cohortCount(cdm[["alldrugs"]]) |>
  filter(number_subjects > 0) |>
  pull("cohort_definition_id")
for (i in seq_along(cohortIdsWithCount)) {
  results[[paste0("index_event_", i)]] <-
    CodelistGenerator::summariseCohortCodeUse(
      x = omopgenerics::cohortCodelist(cdm[["alldrugs"]],
                                       cohortIdsWithCount[[i]]),
      cdm = cdm,
      cohortTable = "alldrugs",
      cohortId = cohortIdsWithCount[[i]],
      timing = "entry",
      countBy = c("record", "person"),
      byConcept = TRUE
    )
}


result_drug_code_all <-  reduce(results, omopgenerics::bind)
