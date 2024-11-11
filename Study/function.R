suppress2 <- function(result,
                      minCellCount = 5) {
  # initial checks
  omopgenerics::assertClass(
    result,
    class = c("tbl", "data.frame", "summarised_result"),
    all = TRUE
  )
  omopgenerics::assertNumeric(
    minCellCount,
    integerish = TRUE,
    min = 0,
    length = 1
  )
  
  # check if already suppressed
  set <- settings(result)
  if ("min_cell_count" %in% colnames(set)) {
    prevSupp <- set |>
      dplyr::select("result_id", "min_cell_count")
    resultId <-
      prevSupp$result_id[as.numeric(prevSupp$min_cell_count) >= minCellCount &
                           !is.na(prevSupp$min_cell_count)]
    if (length(resultId) > 0) {
      "The following result_id(s): {.var {as.character(resultId)}} {?is/are} not
      going to be suppressed, as {?it/they} {?has/have} already been suppressed." |>
        cli::cli_warn()
      resSuppressed <- result |>
        dplyr::filter(!.data$result_id %in% .env$resultId) |>
        omopgenerics:::constructSummarisedResult(set |> dplyr::filter(!.data$result_id %in% .env$resultId)) |>
        suppress2(minCellCount = minCellCount)
      resNotSuppressed <- result |>
        dplyr::filter(.data$result_id %in% .env$resultId) |>
        omopgenerics:::constructSummarisedResult(set |> dplyr::filter(.data$result_id %in% .env$resultId))
      result <- resSuppressed |>
        dplyr::union_all(resNotSuppressed) |>
        dplyr::arrange(.data$result_id) |>
        omopgenerics:::constructSummarisedResult(
          settings(resSuppressed) |>
            dplyr::union_all(settings(resNotSuppressed)) |>
            dplyr::arrange(.data$result_id)
        )
      return(result)
    }
  }
  
  # suppression at cdm_name, group, strata and additional level
  groupSuppress <- c("number subjects", "number records")
  # suppression at cdm_name, group, strata, additional and variable level
  variableSuppress <- c("count",
                        "denominator_count",
                        "outcome_count",
                        "record_count",
                        "subject_count")
  # linked suppression
  linkedSuppression <- c(count = "percentage")
  # value of suppression
  suppressed <- NA_character_
  
  result <- result |>
    # suppress records
    omopgenerics:::suppressCounts(minCellCount) |>
    # suppress records by group
    omopgenerics:::suppressGroup(groupSuppress) |>
    # suppress records by variable
    omopgenerics:::suppressVariable(variableSuppress) |>
    # suppress records by linkage
    omopgenerics:::suppressLinkage(linkedSuppression) |>
    # suppress column
    omopgenerics:::suppressColumn(suppressed)
  
  # update settings
  set <-
    set |> dplyr::mutate("min_cell_count" = as.integer(.env$minCellCount))
  result <-
    omopgenerics::newSummarisedResult(x = result, settings = set)
  
  return(result)
}
