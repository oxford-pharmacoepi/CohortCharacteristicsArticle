# start log --------------------------------------------------------------------
dir.create(here("Results"))
output_folder <- here("Results")
log_file <- paste0(output_folder, "/log_",Sys.Date(),".txt")
logger <- create.logger(logfile = log_file, level = "INFO")
info(logger = logger, "START RUN STUDY")

# if SIDIAP filter cdm$drug_exposure
if (db_name == "SIDIAP") {
  info(logger, "FILTER DRUG EXPOSURE TABLE")
  cdm$drug_exposure <- cdm$drug_exposure %>%
    filter(drug_type_concept_id == 32839) %>%
    compute()
}


# Parameters -------------------------------------------------------------------
info(logger, 'DEFINE PARAMETERS')
drug_cohort_name   <- "drug_cohort"
drug_route_cohort <- "drug_route_cohort"
com_cohort <- "comorbidities_cohort"
ind_cohort <- "indication_cohort"
studyStartDate <- as.Date("2013-01-01")
studyEndDate   <- as.Date("2023-12-31")
minCount <- 5

# cdm snapshot --------------------------- -------------------------------------
info(logger, 'CREATE SNAPSHOT')
snapshot <- cdm |> OmopSketch::summariseOmopSnapshot()
# generate cohorts -------------------------------------------------------------
info(logger, 'INSTANTIATE COHORTS')
source(here("cohortCreation.R"))

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





