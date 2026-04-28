# Example script that walks through running ARTEMIS
devtools::install()
library(ARTEMIS)

# Set Minimum cell count
minCellCount <- 5

# your dbname
cdmName <- NULL

# create your database connection here
con <- DBI::dbConnect(
  your_dbms,
  dbname = "...",
  host = "...",
  user = "...",
  password = "..."
)

# Create the CDM object
cdm <- cdmFromCon(
  con,
  cdmName = cdmName,
  cdmSchema = "main",
  writeSchema = "main")

runArtemis(cdm, "Results")