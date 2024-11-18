# start log --------------------------------------------------------------------
dir.create(here("Results"))
output_folder <- here("Results")
log_file <- paste0(output_folder, "/log_", Sys.Date(),".txt")
logger <- create.logger(logfile = log_file, level = "INFO")
info(logger = logger, "START RUN STUDY")

# create cdm object ------------------------------------------------------------
info(logger, "CREATE CDM OBJECT")
cdm <- CDMConnector::cdmFromCon(
  con = db,
  cdmSchema = cdmSchema, 
  writeSchema = c(schema = writeSchema, prefix = writePrefix),
  cdmName = dbName
)

# if SIDIAP filter cdm$drug_exposure
if (db_name == "SIDIAP") {
  info(logger, "FILTER DRUG EXPOSURE TABLE (SIDIAP ONLY)")
  cdm$drug_exposure <- cdm$drug_exposure |>
    filter(drug_type_concept_id == 32839) |>
    compute()
}

# Parameters -------------------------------------------------------------------
indexCohort   <- "index_cohort"
generalMedications <- "medications_cohort"
generalConditions <- "comorbidities_cohort"
studyStartDate <- as.Date("2013-01-01")
studyEndDate   <- as.Date("2023-12-31")

# cdm snapshot -----------------------------------------------------------------
info(logger, 'CREATE SNAPSHOT')
snapshot <- OmopSketch::summariseOmopSnapshot(cdm)

# generate cohorts -------------------------------------------------------------
info(logger, 'INSTANTIATE COHORTS')
info(logger, "read codelists")
codelistsIndex <- omopgenerics::importCodelist(here::here("Codelists"), "csv")
# codelistMedications <- 
# codelistsConditions <-
iDrugs <- "index_drugs"
iConditions <- "index_conditions"
iInsomnia <- "index_insomnia"

info(logger, "instantiate drug index cohort")
cdm <- DrugUtilisation::generateDrugUtilisationCohortSet(
  cdm = cdm, 
  name = iDrugs, 
  conceptSet = codelistsIndex["any_antipsychotic"], 
  gapEra = 30
)
cdm[[iDrugs]] <- DrugUtilisation::requireIsFirstDrugEntry(cdm[[iDrugs]])

info(logger, "instantiate condition index cohort")
cdm <- CDMConnector::generateConceptCohortSet(
  cdm = cdm, 
  name = iConditions, 
  conceptSet = codelistsIndex[c("dementia", "insomnia_broad")],
  limit = "all",
  end = 0L 
)
cdm[[iConditions]] <- CohortConstructor::requireIsFirstEntry(cdm[[iConditions]])

info(logger, "instantiate insomnia stratifications")
cdm[[iInsomnia]] <- cdm[[iConditions]] |>
  CohortConstructor::subsetCohorts(
    cohortId = omopgenerics::getCohortId(
      cohort = cdm[[iConditions]], cohortName = "insomnia_broad"
    ),
    name = iInsomnia
  ) |>
  CohortConstructor::requireCohortIntersect(
    targetCohortTable = iConditions, 
    targetCohortId = omopgenerics::getCohortId(
      cohort = cdm[[iConditions]], cohortName = "dementia"
    ), 
    window = c(-Inf, -1), 
    intersections = list(0, c(1, Inf))
  )
# update names

info(logger, "bind index cohorts")
cdm <- omopgenerics::bind(
  cdm[[iDrugs]], cdm[[iConditions]], cdm[[iInsomnia]], name = indexCohort
)
cdm <- omopgenerics::dropSourceTable(
  cdm = cdm, name = dplyr::starts_width(c(iDrugs, iConditions, iInsomnia))
)

cdm[[indexCohort]] <- cdm[[indexCohort]] |>
  CohortConstructor::requireInDateRange(
    dateRange = c(studyStartDate, studyEndDate)
  )

dementiaId <- omopgenerics::getCohortId(
  cohort = cdm[[indexCohort]], cohortName = "dementia"
)

info(logger, "instantiate table 1 conditions cohorts")
cdm <- CDMConnector::generateConceptCohortSet(
  cdm = cdm, 
  conceptSet = codelistsConditions, 
  name = generalConditions, 
  limit = "first", 
  end = 0, 
  subsetCohort = indexCohort, 
  subsetCohortId = dementiaId
)

info(logger, "instantiate table 1 medications cohorts")
cdm <- CDMConnector::generateConceptCohortSet(
  cdm = cdm, 
  conceptSet = codelistMedications, 
  name = generalMedications, 
  limit = "all", 
  end = "event_end_date", 
  subsetCohort = indexCohort, 
  subsetCohortId = dementiaId
)

# analyses part ----------------------------------------------------------------
info(logger, "START ANALYSES")

info(logger, "extract cohort counts")
counts <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCohortCount()

info(logger, "extract cohort attritions")
attritions <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCohortAttrition()

info(logger, "extract cohort overlap")
overlap <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCohortOverlap()

info(logger, "extract cohort timing")
timing <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCohortTiming()

info(logger, "extract cohort characteristics")
characteristics <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCharacteristics(
    cohortId = dementiaId, 
    counts = TRUE, 
    demographics = TRUE, 
    ageGroup = list(c(0, 19), c(20, 39), c(40, 59), c(60, 79), c(80, Inf)), 
    cohortIntersectFlag = list(
      "Conditions any time prior" = list(
        targetCohortName = generalConditions, window = c(-Inf, -1)
      ),
      "Medications in the prior year" = list(
        targetCohortName = generalMedications, window = c(-365, -1)
      )
    ),
    tableIntersectCount = list(
      "Number visits prior year" = list(
        tableName = "visit_occurrence", window = c(-365, -1)
      )
    )
  )

info(logger, "extract cohort large scale characteristics")
largeScaleCharacteristics <- cdm[[indexCohort]] |>
  dplyr::filter(cohort_definition_id == dementiaId) |>
  CohortCharacteristics::summariseLargeScaleCharacteristics(
    window = list(
      c(-Inf, -366), c(-365, -31), c(-30, -1), c(0, 0), c(1, 30), c(31, 365), 
      c(366, Inf)
    ), 
    eventInWindow = "condition_occurrence",
    episodeInWindow = "drug_exposure", 
    includeSource = FALSE, 
    minimumFrequency = 0.005, 
    excludedCodes = 0
  )
  
# export results ---------------------------------------------------------------
info(logger, "EXPORT RESULTS")
omopgenerics::exportSummarisedResult(
  snapshot, 
  counts, 
  attritions, 
  overlap, 
  timing, 
  characteristics, 
  largeScaleCharacteristics, 
  minCellCount = minCellCount, 
  path = here::here("Results")
)

# clean tables -----------------------------------------------------------------
cli::cli_inform(c("v" = "STUDY FINISHED"))
tablesCreated <- omopgenerics::listSourceTables(cdm = cdm)
cli::cli_inform(c("The study has created some tables: {.pkg {tablesCreated}}. Do you want to eliminate them?", " " = "1) Yes", " " = "2) No"))
answer <- readline()
while (!answer %in% c("1", "2")) {
  cli::cli_inform(c("x" = "Invalid input. Please choose 1 to delete or 2 to cancel:"))
  answer <- readline()
}
if (answer == "1") {
  omopgenerics::dropSourceTable(cdm = cdm, name = tablesCreated)
  cli::cli_inform(c("v" = "Tables eliminated!"))
} else {
  cli::cli_inform(c("i" = "You can later drop those tables with: `omopgenerics::dropSourceTables(cdm = cdm, name = '...')`"))
}
