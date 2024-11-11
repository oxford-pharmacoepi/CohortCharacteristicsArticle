##generate code list
# ingredient_list
library(readr)
library(CodelistGenerator)
library(dplyr)
library(tibble)

ingredient_csv <-
  readr::read_csv(here("codelistGeneration", "drug_list.csv"))
# create drug cohorts
drug_list <- ingredient_csv |> pull("Substance Name")

atypical <-
  ingredient_csv |> filter(type == "Atypical") |> pull("Substance Name")

typical <- setdiff(drug_list, atypical)

dose_form <-
  list(
    oral = c(
      "Delayed Release Oral Tablet",
      "Disintegrating Oral Tablet",
      "Oral Capsule",
      "Oral Solution",
      "Oral Suspension",
      "Oral Tablet",
      "Extended Release Oral Capsule",
      "Extended Release Oral Tablet"
    ),
    parenteral = c(
      "Injectable Solutiom",
      "Injectable Solution; Injection",
      "Injectable Suspension",
      "Injectable Suspension; Intramuscular Prolonged Release Suspension",
      "Injection",
      "Injection; Injectable Solution",
      "Intramuscular Prolonged Release Suspension; Injectable Suspension",
      "Intramuscular Solution",
      "Prefilled Syringe",
      "Drug Implant"
    ),
    exclude = c("Rectal Suppository", "Topical Solution")
  )

# all drug code
drug_all <- getDrugIngredientCodes(
  cdm,
  name = drug_list,
  nameStyle = "{concept_name}",
  doseForm = NULL,
  doseUnit = NULL,
  routeCategory = NULL,
  ingredientRange = c(1, Inf),
  type = "codelist"
)

drug_to_exclude <- getDrugIngredientCodes(
  cdm,
  name = drug_list,
  nameStyle = "{concept_name}",
  doseForm = c("Rectal Suppository", "Topical Solution"),
  doseUnit = NULL,
  routeCategory = NULL,
  ingredientRange = c(1, Inf),
  type = "codelist"
)

# Convert the lists to data frames for easier manipulation
drug1 <- map(drug_all, ~ tibble(code = .x))
drug2 <- map(drug_to_exclude, ~ tibble(code = .x))

# For each name in list1, filter out codes that are in list2 (if available)
drug3 <- map(names(drug1), function(name) {
  if (name %in% names(drug2)) {
    # If name exists in list2, remove overlapping codes
    drug1[[name]] %>% filter(!code %in% drug2[[name]]$code)
  } else {
    # If name does not exist in list2, keep as is
    drug1[[name]]
  }
})
drug3 <- map(drug3, ~ pull(.x, code))
names(drug3) <- names(drug_all)
# extra groupings
atypical <- snakecase::to_snake_case(atypical)
typical <- snakecase::to_snake_case(typical)

drug3$atypical <- drug3[atypical] |> unlist(use.names = FALSE)
drug3$typical <- drug3[typical] |> unlist(use.names = FALSE)
drug3$`all antipsychotics` <-
  drug3[c(atypical, typical)] |> unlist(use.names = FALSE)

drug_all <- drug3
# convert list to tibble
drug_all_table <-
  dplyr::tibble(name = rep(names(drug_all), lengths(drug_all)),
                concept_id = as.double(unlist((drug_all))))

readr::write_csv(drug_all_table, "drug_all_codelist.csv")




##codelist for different dose form
#dose_form
drug_oral <- getDrugIngredientCodes(
  cdm,
  name = drug_list,
  nameStyle = "{concept_name}",
  doseForm = dose_form[["oral"]],
  doseUnit = NULL,
  routeCategory = NULL,
  ingredientRange = c(1, Inf),
  type = "codelist"
  
)

names(drug_oral) <- paste0(names(drug_oral), "_oral")

drug_parenteral <- getDrugIngredientCodes(
  cdm,
  name = drug_list,
  nameStyle = "{concept_name}",
  doseForm = dose_form[["parenteral"]],
  doseUnit = NULL,
  routeCategory = NULL,
  ingredientRange = c(1, Inf),
  type = "codelist"
  
)

names(drug_parenteral) <-
  paste0(names(drug_parenteral), "_parenteral")


drug_code_route <- c(drug_oral, drug_parenteral)

# convert list to tibble
drug_code_route <-
  dplyr::tibble(name = rep(names(drug_code_route), lengths(drug_code_route)),
                concept_id = as.double(unlist((drug_code_route))))

readr::write_csv(drug_code_route, "drug_route_codelist.csv")
