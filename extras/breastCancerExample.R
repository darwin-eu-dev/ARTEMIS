devtools::load_all()
# ################################################################
# # Test
# ################################################################
# ---------------------- Create TEST CDM -------------------- #
#
# TestGenerator::readPatients.xl(filePath = "mm_test.xlsx", 
#     testName = "MM",
#     outputPath = NULL,
#     cdmVersion = "5.4")

cdm <- TestGenerator::patientsCDM(pathJson = NULL, 
                                  testName = "testBreastCancerRegimens",
                                  cdmVersion = "5.4")

                                  
# ---------------------- Run ARTEMIS ---------------------- #

outputFolder <- "Results_BC"

runArtemis(cdm,
  outputFolder,
  cancers = "breast_cancer",
  generateReportOutput = TRUE,
  reportExamples = 5,
  renderReport = TRUE
)

# ---------------------- Read-in Outputs ---------------------- #
con_dfs <- readRDS(file.path(outputFolder, "con_dfs.rds"))
outputs <- readRDS(file.path(outputFolder, "outputs.rds"))
processed <- readRDS(file.path(outputFolder, "processed.rds"))
eras <- readRDS(file.path(outputFolder, "eras.rds"))
stats <- readRDS(file.path(outputFolder, "stats.rds"))


###################################################################

if (!dir.exists(outputFolder)) {
    dir.create(outputFolder, recursive = TRUE)
  }

# ---------------------- Create Cohorts ---------------------- #
bc_cohort <- CDMConnector::readCohortSet(
  path = system.file("cohorts", "breastCancer.json", package = "ARTEMIS")
)

cdm <- CDMConnector::generateCohortSet(
    cdm = cdm,
    cohortSet = bc_cohort,
    name = "bc_cohort",
    computeAttrition = TRUE,
    overwrite = TRUE
)

# ---------------------- Load Rregimens & Drugs ---------------------- #
validdrugs <- read.csv(system.file("data", "onconet_validdrugs.csv", package = "ARTEMIS"))
regimens <- loadRegimens(condition = "all")
regGroups <- loadGroups()

con_dfs <- list()
stringDFs <- list()

# -------------------------- Pre-process -------------------------- #

df <- con_dfFromCDM(cdm, cohort)

if (!inherits(df$drug_exposure_start_date, "Date")) {
  df <- df |>
    dplyr::mutate(
      drug_exposure_start_date = as.Date(drug_exposure_start_date)
    )
}
con_dfs[[cohort]] <- df

stringDF <- stringDF_from_cdm(con_df = df,
                          validDrugs = validdrugs)


# -------------------------- Alignment -------------------------- #

output <- stringDF |>
generateRawAlignments(
    regimens = regimens,
    g = 0.4,
    Tfac = 0.4,
    method = "PropDiff",
    verbose = 0
)

# -------------------------- Post-Process -------------------------- #


processed <- processAlignments(output,
                                regimens = regimens, 
                                regimenCombine = 28)


## Plot alignments for every patient 

p <- plotAlignment(eras[[1]])
p

