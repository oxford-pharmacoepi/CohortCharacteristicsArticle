# start log --------------------------------------------------------------------
output_folder <- here::here("Results")
dir.create(output_folder, showWarnings = FALSE)
log_file <- file.path(output_folder, paste0(
  "/log_", dbName, "_", format(Sys.time(), "%d_%m_%Y_%H_%M_%S"),".txt"
))
logger <- log4r::create.logger(logfile = log_file, level = "INFO")
log4r::info(logger = logger, "START RUN STUDY")

# create cdm object ------------------------------------------------------------
log4r::info(logger, "CREATE CDM OBJECT")
cdm <- CDMConnector::cdmFromCon(
  con = db,
  cdmSchema = cdmSchema, 
  writeSchema = c(schema = writeSchema, prefix = writePrefix),
  cdmName = dbName
)

# if SIDIAP filter cdm$drug_exposure
if (omopgenerics::cdmName(cdm) == "SIDIAP") {
  log4r::info(logger, "FILTER DRUG EXPOSURE TABLE (SIDIAP ONLY)")
  cdm$drug_exposure <- cdm$drug_exposure |>
    dplyr::filter(drug_type_concept_id == 32839) |>
    dplyr::compute()
}

# Parameters -------------------------------------------------------------------
indexCohort   <- "index_cohort"
generalMedications <- "medications_cohort"
generalConditions <- "comorbidities_cohort"
studyStartDate <- as.Date("2013-01-01")
studyEndDate   <- as.Date("2023-12-31")

# cdm snapshot -----------------------------------------------------------------
log4r::info(logger, 'CREATE SNAPSHOT')
snapshot <- OmopSketch::summariseOmopSnapshot(cdm)

# generate cohorts -------------------------------------------------------------
log4r::info(logger, 'INSTANTIATE COHORTS')
log4r::info(logger, "read codelists")
codelistsIndex <- omopgenerics::importCodelist(here::here("Codelists"), "csv")
codelistMedications <- omopgenerics::importCodelist(
  path = here::here("Codelists", "table 1 medications"), type = "csv"
)
codelistsConditions <- omopgenerics::importCodelist(
  path = here::here("Codelists", "table 1 conditions"), type = "csv"
)

iDrugs <- "index_drugs"
iConditions <- "index_conditions"
iInsomnia <- "index_insomnia"

log4r::info(logger, "instantiate drug index cohort")
cdm <- DrugUtilisation::generateDrugUtilisationCohortSet(
  cdm = cdm, 
  name = iDrugs, 
  conceptSet = codelistsIndex["any_antipsychotic"], 
  gapEra = 30
)
cdm[[iDrugs]] <- DrugUtilisation::requireIsFirstDrugEntry(cdm[[iDrugs]])

log4r::info(logger, "instantiate condition index cohort")
cdm <- CDMConnector::generateConceptCohortSet(
  cdm = cdm, 
  name = iConditions, 
  conceptSet = codelistsIndex[c("dementia", "insomnia_broad")],
  limit = "all",
  end = 0L 
)
cdm[[iConditions]] <- CohortConstructor::requireIsFirstEntry(cdm[[iConditions]])

log4r::info(logger, "instantiate insomnia stratifications")
cdm[[iInsomnia]] <- cdm[[iConditions]] |>
  CohortConstructor::subsetCohorts(
    cohortId = omopgenerics::getCohortId(
      cohort = cdm[[iConditions]], cohortName = "insomnia_broad"
    ),
    name = iInsomnia
  ) |>
  PatientProfiles::addCohortIntersectFlag(
    targetCohortTable = iConditions, 
    targetCohortId = omopgenerics::getCohortId(
      cohort = cdm[[iConditions]], cohortName = "dementia"
    ), 
    window = c(-Inf, -1),
    nameStyle = "prior_dementia",
    name = iInsomnia
  ) |>
  dplyr::mutate(prior_dementia = dplyr::if_else(
    .data$prior_dementia == 1, "prior_dementia", "no_prior_dementia"
  )) |>
  CohortConstructor::stratifyCohorts(
    strata = list("prior_dementia"), name = iInsomnia
  )

log4r::info(logger, "bind index cohorts")
cdm <- omopgenerics::bind(
  cdm[[iDrugs]], cdm[[iConditions]], cdm[[iInsomnia]], name = indexCohort
)
cdm <- omopgenerics::dropSourceTable(
  cdm = cdm, name = dplyr::starts_with(c(iDrugs, iConditions, iInsomnia))
)

cdm[[indexCohort]] <- cdm[[indexCohort]] |>
  CohortConstructor::requireInDateRange(
    dateRange = c(studyStartDate, studyEndDate)
  )

dementiaId <- omopgenerics::getCohortId(
  cohort = cdm[[indexCohort]], cohortName = "dementia"
)

log4r::info(logger, "instantiate table 1 conditions cohorts")
cdm <- CDMConnector::generateConceptCohortSet(
  cdm = cdm, 
  conceptSet = codelistsConditions, 
  name = generalConditions, 
  limit = "first", 
  end = 0, 
  subsetCohort = indexCohort, 
  subsetCohortId = dementiaId
)

log4r::info(logger, "instantiate table 1 medications cohorts")
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
log4r::info(logger, "START ANALYSES")

log4r::info(logger, "extract cohort counts")
counts <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCohortCount()

log4r::info(logger, "extract cohort attritions")
attritions <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCohortAttrition()

log4r::info(logger, "extract cohort overlap")
overlap <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCohortOverlap()

log4r::info(logger, "extract cohort timing")
timing <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCohortTiming()

log4r::info(logger, "extract cohort characteristics")
characteristics <- cdm[[indexCohort]] |>
  CohortCharacteristics::summariseCharacteristics(
    cohortId = dementiaId, 
    counts = TRUE, 
    demographics = TRUE, 
    ageGroup = list(c(0, 19), c(20, 39), c(40, 59), c(60, 79), c(80, Inf)), 
    cohortIntersectFlag = list(
      "Conditions any time prior" = list(
        targetCohortTable = generalConditions, window = c(-Inf, -1)
      ),
      "Medications in the prior year" = list(
        targetCohortTable = generalMedications, window = c(-365, -1)
      )
    ),
    tableIntersectCount = list(
      "Number visits prior year" = list(
        tableName = "visit_occurrence", window = c(-365, -1)
      )
    )
  )

log4r::info(logger, "extract cohort large scale characteristics")
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
log4r::info(logger, "EXPORT RESULTS")
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
