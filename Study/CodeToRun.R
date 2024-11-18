# Install dependencies -----
#install.packages("renv") # if not already installed, install renv from CRAN
# run renv::install() and renv::restore() this should prompt you to install the various packages required for the study
renv::activate()
renv::restore()

# Connect to database ----
# please see examples how to connect to the database here:
# https://darwin-eu.github.io/CDMConnector/articles/a04_DBI_connection_examples.html
library(DBI)
library(RPostgres)

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
dbName <- "..."

# minimum number of counts to be reported
minCellCount <- 5

# Run the study code
source(here::here("RunStudy.R"))
