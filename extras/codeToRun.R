# Script that walks through running ARTEMIS
library(ARTEMIS)

# Fill in your db details below
cdmName <- ""
cdmDatabaseSchema <- ""
resultsDatabaseSchema <- ""

# create your database connection here
conn <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = "...", 
  host = "...",
  user = "...",
  password = "..."
)

# Create the CDM object
cdm <- CDMConnector::cdmFromCon(
  conn,
  cdmName = cdmName,
  cdmSchema = cdmDatabaseSchema,
  writeSchema = resultsDatabaseSchema)

runArtemis(cdm, "Results", runAML = TRUE, runMM = FALSE, generateReportOutput = TRUE)
