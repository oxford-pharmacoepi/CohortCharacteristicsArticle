
# renv::activate()
# renv::restore()

library(CohortCharacteristics)
library(CDMConnector)
library(DBI)
library(here)
library(OmopSketch)
library(PatientProfiles)

# create a connection to your database
con <- dbConnect("...")

# cdm schema of your database, this schema must contain your omop tables
cdmSchema <- "..."

# write schema of your database, this schema will be used to write intermediate
# tables all intermediate tables will be drop by last command, comment it out
# if you wish to keep those intermediate tables.
writeSchema <- "..."

# name of your cdm instance
cdmName <- "..."

# count under this snumber will be suppressed
minCellCount <- 5

# run study
source(here("RunStudy.R"))

# delete intermediate tables
source(here("CleanTables.R"))
