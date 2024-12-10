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
data <- prepareResult(result, resultList)
filterValues <- defaultFilterValues(result, resultList)

save(data, filterValues, file = file.path(getwd(), "data", "shinyData.RData"))

rm(result, filterValues, resultList, data)
