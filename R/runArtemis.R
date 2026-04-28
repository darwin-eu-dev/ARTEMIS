#' Run the ARTEMIS pacakge
#'
#' @param cdm A CDM reference object created by `CDMConnector::cdmFromCon`
#' @param outputFolder The full path to a folder where the results should be saved
#' 
#' @return NULL (invisibly). Results are written to `outputFolder`.
#' 
#' @export
runArtemis <- function(cdm, outputFolder = "Results"){

  # ===========================================================================
  # Step 0: Setup — logger, version, database detection
  # ===========================================================================

  if (!dir.exists(outputFolder)) {
  dir.create(outputFolder, recursive = TRUE)
  }

  logFile <- file.path(outputFolder, "log.txt")
  logger <- log4r::logger(
      threshold = "INFO",
      appenders = list(
          log4r::console_appender(layout = log4r::default_log_layout()),
          log4r::file_appender(file = logFile)
      )
  )

  # Save CDM snapshot at the start (before any modifications)
  snap <- CDMConnector::snapshot(cdm)
  write.csv(snap, file = file.path(outputFolder, "cdm_snapshot.csv"), row.names = FALSE)
  log4r::info(logger, "[Step 0] CDM snapshot saved")

  # ===========================================================================
  # Step 1: Create Cohorts
  # ===========================================================================

  log4r::info(logger, "[Step 1] Creating cohorts (MM, AML)")

  # MM cohort from ConceptSet json
  mm_codes <- omopgenerics::importConceptSetExpression(
      path = system.file("cohorts", "mm_narrow.json", package = "ARTEMIS")
  ) |> CodelistGenerator::asCodelist(cdm = cdm)
  mm_codes <- unlist(mm_codes)

  log4r::info(logger, "Generate MM cohort from concept sets")
  cdm <- CDMConnector::generateConceptCohortSet(
      cdm = cdm,
      conceptSet = list(
          "mm_cohort_1" = mm_codes
      ),
      end = "observation_period_end_date",
      limit = "first",
      name = "mm_cohort",
      overwrite = TRUE
  )


  # AML cohort from is a CohortSet json
  aml_cohort <- CDMConnector::readCohortSet(
    path = system.file("cohorts", "aml.json", package = "ARTEMIS")
  )

  log4r::info(logger, "Generate AML cohort from sohortSet")
  cdm <- CDMConnector::generateCohortSet(
      cdm = cdm,
      cohortSet = aml_cohort,
      name = "aml_cohort",
      computeAttrition = TRUE,
      overwrite = TRUE
  )

  cohorts <- c("aml_cohort", "mm_cohort")

  # ===========================================================================
  # Step 2: Preprocessing
  # ===========================================================================
  log4r::info(logger, "[Step 2] Preprocessing")

  validdrugs <- loadDrugs()
  regimens <- loadRegimens(condition = "all")
  regGroups <- loadGroups()
  
  con_dfs <- list()
  stringDFs <- list()
 
  for (cohort in cohorts) {
    log4r::info(logger, sprintf("create con_df for %s", cohort))
    df <- dfFromCDM(cdm, cohort)
    
    # check dates are correctly written
    df$drug_exposure_start_date <- as.POSIXct(df$drug_exposure_start_date,
                                              origin = "1970-01-01",
                                              tz = "UTC")
    con_dfs[[cohort]] <- df

    # Prepare a data.frame of patient drug records used in the alignment step
    stringDF <- stringDF_from_cdm(con_df = con_df,
                              validDrugs = validdrugs)
    
    log4r::info(logger, sprintf("create stringDF for %s", cohort))
    stringDFs[[cohort]] <- stringDF
  } 

  log4r::info(logger, "saving con_dfs, stringDFs")
  saveRDS(con_dfs, "con_dfs.rds")
  saveRDS(stringDFs, "stringDFs.rds")

  # ===========================================================================
  # Step 3: Alginment & post-processing
  # ===========================================================================

  log4r::info(logger, "[Step 3] Preprocess & prep for alignment")

  outputs <- list()
  processed <- list()
  eras <- list()
  stats <- list()

  for (cohort in cohorts) {
    log4r::info(logger, sprintf("run alginments for %s", cohort))
    outputs[[cohort]] <- stringDFs[[cohort]] |>
    generateRawAlignments(
        regimens = regimens,
        g = 0.4,
        Tfac = 0.4,
        method = "PropDiff",
        verbose = 0
    )

    ## Post-process 
    log4r::info(logger, sprintf("run postprocessing for %s", cohort))
    processed[[cohort]] <- outputs[[cohort]] |>
        processAlignments(regimens = regimens, 
                          regimenCombine = 28)

    log4r::info(logger, sprintf("get drug eras for %s", cohort))
    eras[[cohort]] <- processed[[cohort]] |> 
        calculateEras()
    
    log4r::info(logger, sprintf("get stats for %s", cohort))
    stats[[cohort]] <- eras[[cohort]] |> 
    generateRegimenStats()
  }

  log4r::info(logger, "saving outputs & postprocessed")
  saveRDS(outputs, "outputs.rds")
  saveRDS(processed, "processed.rds")
  saveRDS(eras, "eras.rds")
  saveRDS(stats, "stats.rds")

  # ===========================================================================
  # Step 4: Save outputs
  # ===========================================================================

  log4r::info(logger, "Disconnecting from database")
  CDMConnector::cdmDisconnect(cdm)
}