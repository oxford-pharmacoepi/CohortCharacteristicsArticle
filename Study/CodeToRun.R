# Install dependencies -----
#install.packages("renv") # if not already installed, install renv from CRAN
# run renv::install() and renv::restore() this should prompt you to install the various packages required for the study
renv::activate()
renv::restore()

library(CDMConnector)
library(DrugUtilisation)
library(purrr)
library(CodelistGenerator)
library(DBI)
library(log4r)
library(dplyr)
library(here)
library(RPostgres)
library(SqlRender)
library(zip)
library(readr)
library(CohortCharacteristics)
library(PatientProfiles)
library(snakecase)
library(readr)
library(CohortSurvival)
library(CirceR)
library(IncidencePrevalence)
library(OmopSketch)
# Connect to database ----
# please see examples how to connect to the database here:
# https://darwin-eu.github.io/CDMConnector/articles/a04_DBI_connection_examples.html
db <- dbConnect("...")

# parameters to connect to create cdm object ----
# name of the schema where cdm tables are located
cdmSchema <- "..."

# name of a schema in the database where you have writing permission
writeSchema <- "..."

# combination of at least 5 letters + _ (eg. "abcde_") that will lead any table
# written in the write schema
writePrefix <- "..."

# name of the database, use acronym in capital letters (eg. "CPRD GOLD")
#PLEASE USE ONE OF BELOW FOR YOUR CORRESPONDING DATABASE NAME THAT MATCHES THE PROTOCOL
# "SIDIAP"
# "IPCI"
# "DK-DHR" 
# "IQVIA DA Germany"
# "IQVIA LPD Belgium" 
# "NAJS Croatia"

db_name <- "..."

# minimum number of counts to be reported
minCellCount <- 5
#create cdm object
cdm <- cdm_from_con(
  db,
  cdm_schema = cdmSchema, 
  write_schema = c(schema = writeSchema,
                   prefix = writePrefix)
)

# Run the study code ----
source(here("runStudy.R"))

