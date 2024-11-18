# start log --------------------------------------------------------------------
dir.create(here("Results"))
output_folder <- here("Results")
log_file <- paste0(output_folder, "/log_", Sys.Date(),".txt")
logger <- create.logger(logfile = log_file, level = "INFO")
info(logger = logger, "START RUN STUDY")

# create cdm object ------------------------------------------------------------
cdm <- CDMConnector::cdmFromCon(
  con = db,
  cdmSchema = cdmSchema, 
  writeSchema = c(schema = writeSchema, prefix = writePrefix),
  cdmName = dbName
)

# if SIDIAP filter cdm$drug_exposure
if (db_name == "SIDIAP") {
  info(logger, "FILTER DRUG EXPOSURE TABLE")
  cdm$drug_exposure <- cdm$drug_exposure |>
    filter(drug_type_concept_id == 32839) |>
    compute()
}

# Parameters -------------------------------------------------------------------
info(logger, 'DEFINE PARAMETERS')
indexCohort   <- "indexCohort"
generalMedications <- "medications_cohort"
generalConditions <- "comorbidities_cohort"
studyStartDate <- as.Date("2013-01-01")
studyEndDate   <- as.Date("2023-12-31")
minCellCount <- 5

# cdm snapshot -----------------------------------------------------------------
info(logger, 'CREATE SNAPSHOT')
snapshot <- OmopSketch::summariseOmopSnapshot(cdm)

# generate cohorts -------------------------------------------------------------
info(logger, 'INSTANTIATE COHORTS')
info(logger = logger, "LOAD IN CODELIST")

drug_all <- readr::read_csv(here::here("Codelists", "drug_all_codelist.csv"))

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


# study code -------------------------------------------------------------
info(logger, 'RUN STUDY')
source(here("studyCode.R"))
# zip all results ----
info(logger, "zip all results")

zip(
  zipfile = here(
    output_folder, paste0("P3-C1-012-StudyResults-", db_name, ".zip")
  ),
  files = list.files(output_folder),
  root = output_folder
)





