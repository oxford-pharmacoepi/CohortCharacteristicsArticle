# source needed functions ----
source(here("Analyses", "helpers.R"))

# parameters ----
results <- here("Results")
if (!dir.exists(results)) dir.create(results)
createLogger(results, cdmName)
log("Log created")
ageGroup <- list(c(0, 19), c(20, 39), c(40, 59), c(60, 79), c(80, Inf))
strata <- omopgenerics::combineStrata(c("age_group", "sex"))

# create the cdm object ----
log("creating cdm object")
cdm <- cdmFromCon(
  con = con, cdmSchema = cdmSchema, writeSchema = writeSchema, cdmName = cdmName
)

# export cdm snapshot ----
log("extract cdm snapshot")
resultSnapshot <- summariseOmopSnapshot(cdm = cdm)

# create cohorts ----
cdm <- generateConceptCohortSet(
  cdm = cdm,
  conceptSet = list(sinusitis = c(4294548, 40481087, 257012)),
  limit = "all",
  end = 0,
  name = "my_cohort"
)

# add stratification ----
log("add demographics")
cdm$my_cohort <- cdm$my_cohort |>
  addDemographics(
    age = FALSE,
    ageGroup = ageGroup,
    sex = TRUE,
    priorObservation = FALSE,
    futureObservation = FALSE,
    dateOfBirth = FALSE,
    name = "my_cohort")

# summarise counts ----
log("summarise counts")
resultCounts <- summariseCohortCount(cdm$my_cohort, strata = strata)

# export results -----
log("results exported")
exportSummarisedResult(
  resultSnapshot,
  resultCounts,
  minCellCount = minCellCount,
  path = results
)

log("STUDY FINISHED")
log("results in: '{results}'")
