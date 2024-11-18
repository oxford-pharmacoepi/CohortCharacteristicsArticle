# These codelists were generated using an omop instance with:
# cdm version:
# vocabulary version: MIKE TO POPULATE!!!
# here the code for reproducibility purposes

ingredients <- c(
  "amisulpride", "aripiprazole", "chlorprothixene", "clozapine", "fluphenazine",
  "fluspirilene", "haloperidol", "olanzapine", "paliperidone", "perphenazine",
  "pimozide", "pipamperone", "prochlorperazine", "promazine", "prothipendyl",
  "quetiapine", "risperidone", "sulpiride", "ziprasidone", "zuclopenthixol"
)

codes <- CodelistGenerator::getDrugIngredientCodes(
  cdm,
  name = ingredients,
  nameStyle = "{concept_name}",
  doseForm = NULL,
  doseUnit = NULL,
  routeCategory = NULL,
  ingredientRange = c(1, Inf),
  type = "codelist"
) |>
  unlist() |>
  unique()

exclude <- CodelistGenerator::getDrugIngredientCodes(
  cdm,
  name = ingredients,
  nameStyle = "{concept_name}",
  doseForm = c("Rectal Suppository", "Topical Solution"),
  doseUnit = NULL,
  routeCategory = NULL,
  ingredientRange = c(1, Inf),
  type = "codelist"
) |>
  unlist() |>
  unique()

# make sure they have same order
codelist <- list(any_antipsychotic = codes[!codes %in% exclude])

omopgenerics::exportCodelist(codelist, path = here::here("Codelists"), type = "csv")

# codes <- CodelistGenerator::codesFromCohort(here::here("Codelists", "indication"), cdm = cdm)
# omopgenerics::exportCodelist(codes, path = here::here("Codelists"), type = "csv")

codes <- CodelistGenerator::getATCCodes(cdm = cdm)
omopgenerics::exportCodelist(codes, path = here::here("Codelists", "Table 1 medications"), type = "csv")

codes <- CodelistGenerator::getICD10StandardCodes(cdm = cdm, level = "ICD10 Chapter")
omopgenerics::exportCodelist(codes, path = here::here("Codelists", "Table 1 conditions"), type = "csv")

