################################################################
# Test
################################################################
# TestGenerator::readPatients.xl(filePath = "mm_test.xlsx", 
#     testName = "MM",
#     outputPath = NULL,
#     cdmVersion = "5.4")

# cdm <- TestGenerator::patientsCDM(pathJson = NULL, 
#                                   testName = "MM",
#                                   cdmVersion = "5.4")

# runArtemis(cdm, "Results")
################################################################

# Example script that walks through running ARTEMIS
library(ARTEMIS)

# your dbname
cdmName <- "IPCI"
cdmDatabaseSchema <- ""
resultsDatabaseSchema <- ""

# create your database connection here
con <- DBI::dbConnect(
  RPostgres::Postgres(),
  dbname = "...", # 
  host = "...",
  user = "...",
  password = "..."
)

# Create the CDM object
cdm <- CDMConnector::cdmFromCon(
  con,
  cdmName = cdmName,
  cdmSchema = cdmDatabaseSchema,
  writeSchema = resultsDatabaseSchema)

runArtemis(cdm, "Results")
