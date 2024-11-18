# create a connection to your database
con <- duckdb::dbConnect(duckdb::duckdb(), CDMConnector::eunomiaDir())

# cdm schema of your database, this schema must contain your omop tables
cdmSchema <- "main"

# write schema of your database, this schema will be used to write intermediate
# tables all intermediate tables will be drop by last command, comment it out
# if you wish to keep those intermediate tables.
writeSchema <- "main"

# name of your cdm instance
cdmName <- "eunomia"

# count under this snumber will be suppressed
minCellCount <- 5

# run study
source(here("RunStudy.R"))

# delete intermediate tables
source(here("CleanTables.R"))
