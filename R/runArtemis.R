#' Run the ARTEMIS package
#'
#' Cohorts are created with [P4C5006::createCancerCohorts()] (the
#' \href{https://github.com/darwin-eu-studies/P4-C5-006}{P4-C5-006} phenotype
#' library) and the requested cancer cohorts are then aligned against their
#' matching treatment regimens.
#'
#' @param cdm A CDM reference object created by `CDMConnector::cdmFromCon`
#' @param outputFolder The full path to a folder where the results should be saved
#' @param cancers Character vector of cancer cohorts (from P4C5006) to analyse.
#'   One or more of "bladder_cancer", "breast_cancer", "colorectal_cancer",
#'   "lung_cancer", "melanoma_of_skin", "oesophageal_cancer", "prostate_cancer".
#'   Defaults to breast and lung cancer.
#' @param generateReportOutput Whether to generate a Quarto report from saved ARTEMIS outputs
#' @param reportExamples Number of example subjects with longer drug records to include per cohort
#' @param renderReport Whether to render the Quarto report immediately when Quarto is available
#'
#' @return NULL (invisibly). Results are written to `outputFolder`.
#'
#' @export
runArtemis <- function(
  cdm,
  outputFolder = "Results",
  cancers = c("breast_cancer", "lung_cancer"),
  generateReportOutput = FALSE,
  reportExamples = 5,
  renderReport = FALSE
){

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
  on.exit(log4r::info(logger, "runArtemis finished"), add = TRUE)

  # Save CDM snapshot at the start (before any modifications)
  snap <- CDMConnector::snapshot(cdm)
  write.csv(snap, file = file.path(outputFolder, "cdm_snapshot.csv"), row.names = FALSE)
  log4r::info(logger, "[Step 0] CDM snapshot saved")

  # ===========================================================================
  # Step 1: Create cancer cohorts via the P4-C5-006 phenotype library
  # ===========================================================================

  # Maps each supported P4C5006 cancer cohort to the regimen condition keyword
  # it is aligned against.
  cancer_regimen_conditions <- list(
    bladder_cancer     = "bladder",
    breast_cancer      = "breast",
    colorectal_cancer  = "colorectal",
    lung_cancer        = "lung",
    melanoma_of_skin   = "melanoma",
    oesophageal_cancer = "esophageal",
    prostate_cancer    = "prostate"
  )

  unknown <- setdiff(cancers, names(cancer_regimen_conditions))
  if (length(unknown) > 0) {
    stop("Unknown cancer cohort(s): ", paste(unknown, collapse = ", "),
         ".\nValid options: ", paste(names(cancer_regimen_conditions), collapse = ", "))
  }

  log4r::info(logger, "[Step 1] Creating cancer cohorts via P4C5006::createCancerCohorts")

  cdm <- P4C5006::createCancerCohorts(
    cdm = cdm,
    concept_sets_folder = "cancer_cohorts",
    name = "cancer_cohorts"
  )

  # createCancerCohorts() builds all cancer types into a single cohort table;
  # split out the requested cancers into their own cohort tables for ARTEMIS.
  cohort_settings <- omopgenerics::settings(cdm[["cancer_cohorts"]])

  cohorts <- c()
  cohort_condition_patterns <- list()
  for (cancer in cancers) {
    cohort_id <- cohort_settings |>
      dplyr::filter(cohort_name == cancer) |>
      dplyr::pull(cohort_definition_id)

    if (length(cohort_id) == 0) {
      log4r::warn(logger, sprintf("%s not found in cancer_cohorts; skipping", cancer))
      next
    }

    cohortTable <- paste0(cancer, "_cohort")
    cdm[[cohortTable]] <- CohortConstructor::subsetCohorts(
      cohort = cdm[["cancer_cohorts"]],
      cohortId = cohort_id,
      name = cohortTable
    )
    cohorts <- c(cohorts, cohortTable)
    cohort_condition_patterns[[cohortTable]] <- cancer_regimen_conditions[[cancer]]
  }

  # ===========================================================================
  # Step 2: Preprocessing
  # ===========================================================================
  log4r::info(logger, "[Step 2] Preprocessing")

  validdrugs <- read.csv(system.file("concept_sets", "onconet_validdrugs.csv", package = "ARTEMIS"))
  regimens <- loadRegimens(condition = "all")
  regGroups <- loadGroups()

  con_dfs <- list()
  stringDFs <- list()
 
  for (cohort in cohorts) {
    log4r::info(logger, sprintf("create con_df for %s", cohort))
    df <- con_dfFromCDM(cdm, cohort)

    cohort_rows <- nrow(df)
    
    if (cohort_rows == 0){
      log4r::info(logger, sprintf("%s is empty, removing from cohort list so further analysis is not run", cohort))
      cohorts <- cohorts[cohorts != cohort]
      next
    }

    if (!inherits(df$drug_exposure_start_date, "Date")) {
      df <- df |>
        dplyr::mutate(
          drug_exposure_start_date = as.Date(drug_exposure_start_date)
        )
    }
    con_dfs[[cohort]] <- df

    # Prepare a data.frame of patient drug records used in the alignment step
    stringDF <- stringDF_from_cdm(con_df = df,
                              validDrugs = validdrugs)
    
    log4r::info(logger, sprintf("create stringDF for %s", cohort))
    stringDFs[[cohort]] <- stringDF
  } 

  log4r::info(logger, "saving con_dfs, stringDFs")
  saveRDS(con_dfs, file.path(outputFolder, "con_dfs.rds"))
  saveRDS(stringDFs, file.path(outputFolder, "stringDFs.rds"))

  # ===========================================================================
  # Step 3: Alginment & post-processing
  # ===========================================================================

  log4r::info(logger, "[Step 3] Preprocess & prep for alignment")

  outputs <- list()
  processed <- list()
  eras <- list()
  stats <- list()

  if (length(names(stringDFs)) == 0) {
    log4r::warn(logger, "No cohorts contained valid drug exposures; skipping alignment")
    return(invisible(NULL))
  }

  for (cohort in names(stringDFs)) {
    pattern <- cohort_condition_patterns[[cohort]]
    cohort_regimens <- if (!is.null(pattern)) {
      regimens |> dplyr::filter(grepl(pattern, tolower(condition)))
    } else {
      regimens
    }

    log4r::info(logger, sprintf("run alginments for %s", cohort))
    outputs[[cohort]] <- stringDFs[[cohort]] |>
    generateRawAlignments(
        regimens = cohort_regimens,
        g = 0.4,
        Tfac = 0.4,
        method = "PropDiff",
        verbose = 0
    )

    ## Post-process
    log4r::info(logger, sprintf("run postprocessing for %s", cohort))
    processed[[cohort]] <- outputs[[cohort]] |>
        processAlignments(regimens = cohort_regimens,
                          regimenCombine = 28)

    log4r::info(logger, sprintf("get drug eras for %s", cohort))
    eras[[cohort]] <- processed[[cohort]] |> 
        calculateEras()
    
    log4r::info(logger, sprintf("get stats for %s", cohort))
    stats[[cohort]] <- eras[[cohort]] |>
      generateRegimenStats()
  }

  # ===========================================================================
  # Step 4: Save outputs & generate report
  # ===========================================================================

  saveRDS(outputs, file.path(outputFolder,"outputs.rds"))
  saveRDS(processed, file.path(outputFolder, "processed.rds"))
  saveRDS(eras, file.path(outputFolder, "eras.rds"))
  saveRDS(stats, file.path(outputFolder, "stats.rds"))

  if (generateReportOutput) {
    log4r::info(logger, "Generating ARTEMIS report")
    generateReport(
      outputFolder = outputFolder,
      nExamples = reportExamples,
      render = renderReport
    )
  }

  log4r::info(logger, "Leaving database connection open for caller-managed cleanup")
  invisible(NULL)
}
