source("function.R")

##objective 1 - demographic characteristics
info(logger = logger, "demographic characteristics")

# table one
tableOne <-
  cdm[[drug_cohort_name]] |>
  CohortCharacteristics::summariseCharacteristics(
    ageGroup = list(
      "0-64" = c(0, 64),
      "65-74" = c(65, 74),
      "75-84" = c(75, 84),
      "85+" = c(85, 150)
    ),
    cohortIntersectFlag = list(
      "comorbidities (anytime prior)" = list(targetCohortTable = com_cohort,
                                             window = list(c(-Inf, 0))),
      "comorbidities (0 to 30 days prior)" = list(targetCohortTable = com_cohort,
                                                  window = list(c(-30, 0))),
      "indications (0 to 7 days prior)" = list(targetCohortTable = ind_cohort,
                                               window = list(c(-7, 0))),
      "indications (0 to 30 days prior)" = list(targetCohortTable = ind_cohort,
                                                window = list(c(-30, 0))),
      "indications (anytime prior)" = list(targetCohortTable = ind_cohort,
                                           window = list(c(-Inf, 0)))
    )
  )

##objective 2 - IncidencePrevalence
info(logger = logger, "INCIDENCE")

cdm <- IncidencePrevalence::generateDenominatorCohortSet(
  cdm = cdm,
  name = "denominator",
  cohortDateRange = c(studyStartDate, studyEndDate),
  ageGroup = list(c(0, 64),
                  c(65, 74),
                  c(75, 84),
                  c(85, 150),
                  c(0, 150)),
  sex = c("Male", "Female", "Both"),
  daysPriorObservation = 365,
  requirementInteractions = TRUE
)

inc <- IncidencePrevalence::estimateIncidence(
  cdm = cdm,
  denominatorTable = "denominator",
  outcomeTable = drug_cohort_name,
  interval = "Years",
  minCellCount = minCount,
  outcomeWashout = Inf,
  repeatedEvents = FALSE
)
## objective 3
if (!db_name %in% c("NAJS Croatia")) {
  ##objective 3 - drug Utilisation
  info(logger = logger, "DRUG UTILISATION")
  #all route
  drug <- cdm[[drug_cohort_name]] |> addCohortName()
  nonZeroConcepts <- settings(cdm[[drug_cohort_name]]) |>
    left_join(cohortCount(cdm[[drug_cohort_name]]), by = "cohort_definition_id") |>
    filter(number_subjects > 0,!cohort_name %in% c("atypical", "typical", "all_antipsychotics")) |>
    pull("cohort_name")
  
  
  result <- list()
  
  in1 <-
    readr::read_csv(here("codelistGeneration", "drug_list.csv")) |>
    mutate(`Substance Name` = `Substance Name` |> to_snake_case())
  in2 <-
    readr::read_csv(here("codelistGeneration", "drug_list.csv")) |>
    mutate(`Substance Name` = paste0(`Substance Name`, "_oral") |> to_snake_case())
  in3 <-
    readr::read_csv(here("codelistGeneration", "drug_list.csv")) |>
    mutate(`Substance Name` = paste0(`Substance Name`, "_parenteral") |> to_snake_case())
  #for drug utilization study
  ingredient_final <- rbind(in1, in2, in3)
  
  for (k in nonZeroConcepts) {
    id <-
      ingredient_final |> filter(`Substance Name` == k) |> pull(IngredientID)
    
    result[[k]] <-
      drug |> filter(cohort_name == k) |>
      addDemographics(ageGroup = list(c(0, 64), c(65, 150))) |>
      summariseDrugUtilisation(
        strata = list("age_group", "sex"),
        ingredientConceptId = id,
        gapEra = 30,
        numberExposures = TRUE,
        numberEras = FALSE,
        exposedTime = TRUE,
        timeToExposure = FALSE,
        initialQuantity = FALSE,
        cumulativeQuantity = FALSE,
        initialDailyDose = TRUE,
        cumulativeDose = TRUE
      )
    
  }
  
  result_drug_all <-  reduce(result, omopgenerics::bind)
  
  
  #by route
  
  drug <- cdm[[drug_route_cohort]] |> addCohortName()
  nonZeroConcepts <- settings(cdm[[drug_route_cohort]]) |>
    left_join(cohortCount(cdm[[drug_route_cohort]]), by = "cohort_definition_id") |>
    filter(number_subjects > 0,!cohort_name %in% c("atypical", "typical", "all_antipsychotics")) |>
    pull("cohort_name")
  results2 <- list()
  for (k in nonZeroConcepts) {
    id <-
      ingredient_final |> filter(`Substance Name` == k) |> pull(IngredientID)
    
    results2[[k]] <-
      drug |> filter(cohort_name == k) |>
      addDemographics(ageGroup = list(c(0, 64), c(65, 150))) |>
      filter(cohort_name == k) |> summariseDrugUtilisation(
        strata = list("age_group", "sex"),
        ingredientConceptId = id,
        gapEra = 30,
        numberExposures = TRUE,
        numberEras = FALSE,
        exposedTime = TRUE,
        timeToExposure = FALSE,
        initialQuantity = FALSE,
        cumulativeQuantity = FALSE,
        initialDailyDose = TRUE,
        cumulativeDose = TRUE
      )
    
  }
  
  result_drug_route <-  reduce(results2, omopgenerics::bind)
  
  result_drug_all <-
    omopgenerics::bind(result_drug_all, result_drug_route)
} else {
  result_drug_all <- omopgenerics::emptySummarisedResult()
}
##objective 4 survival analysis
if (!db_name %in% c("IQVIA DA Germany",
                    "IQVIA LPD Belgium",
                    "NAJS Croatia")) {
  info(logger = logger, "SURVIVAL ANALYSIS")
  # death cohort
  cdm <- CohortSurvival::generateDeathCohortSet(cdm = cdm,
                                                name = "death_cohort",
                                                cohortTable = drug_cohort_name)
  
  cdm[[drug_cohort_name]] <- cdm[[drug_cohort_name]] |>
    addDemographics(ageGroup = list(c(0, 64), c(65, 150))) |>
    compute(name = drug_cohort_name, temporary = FALSE)
  
  survival <- CohortSurvival::estimateSingleEventSurvival(
    cdm,
    targetCohortTable = drug_cohort_name,
    outcomeCohortTable = "death_cohort",
    followUpDays = 365,
    eventGap = 365,
    strata = list(c("age_group"),
                  c("sex"))
  )
} else {
  survival <- omopgenerics::emptySummarisedResult()
}
##export results
info(logger = logger, "EXPORT RESULTS")


final_results <- omopgenerics::bind(
  inc,
  tableOne,
  survival,
  result_drug_all,
  drug_attrition,
  snapshot,
  result_drug_code_all
)

final_results <- final_results |> suppress2(minCellCount = 5)

omopgenerics::exportSummarisedResult(
  final_results,
  fileName = paste0("results_", db_name, ".csv"),
  minCellCount = minCount,
  path = output_folder
)
