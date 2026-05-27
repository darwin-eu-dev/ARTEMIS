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

runArtemis(cdm, 
          "Results_IKNL_BC", 
          runAML = FALSE, 
          runMM = FALSE, 
          runBC = TRUE,
          generateReportOutput = TRUE)

# ------------------ Preview Report (run from terminal) ------------------ #
# quarto preview path/to/outputFolder 

# ---------------------- Read-in Generated Outputs ---------------------- #
con_dfs <- readRDS(file.path(outputFolder, "con_dfs.rds"))
outputs <- readRDS(file.path(outputFolder, "outputs.rds"))
processed <- readRDS(file.path(outputFolder, "processed.rds"))
eras <- readRDS(file.path(outputFolder, "eras.rds"))
stats <- readRDS(file.path(outputFolder, "stats.rds"))


# ---------------------- Plot Alignment for 1 Example Patient ---------------------- #

p <- plotAlignment(eras[[1]])
p