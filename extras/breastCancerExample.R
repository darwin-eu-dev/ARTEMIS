# ################################################################
# # Test
# ################################################################
# TestGenerator::readPatients.xl(filePath = "mm_test.xlsx", 
#     testName = "MM",
#     outputPath = NULL,
#     cdmVersion = "5.4")

# cdm <- TestGenerator::patientsCDM(pathJson = NULL, 
#                                   testName = "AML",
#                                   cdmVersion = "5.4")

# runArtemis(cdm, 
#   "Results_AML",
#   runMM = FALSE,
#   runAML = TRUE,
#   generateReportOutput = TRUE,
#   reportExamples = 5,
#   renderReport = TRUE

# )
# ################################################################

library(dplyr)
library(CDMConnector)
library(ARTEMIS)

# Get breast cancer test CDM
cdm <- TestGenerator::patientsCDM(pathJson = NULL, 
                                  testName = "BC",
                                  cdmVersion = "5.4"
                                )


# create cohort that has all cdm patients
all_persons_cohort <- cdm$person %>%
  inner_join(cdm$observation_period, by = "person_id") %>%
  select(person_id, observation_period_start_date) %>%
  mutate(
    cohort_definition_id = 1,
    cohort_start_date = observation_period_start_date,
    cohort_end_date = observation_period_start_date
  ) %>%
  select(person_id, cohort_definition_id, cohort_start_date, cohort_end_date)

# Copy cohort table to database schema (example schema: cdm_results)
cdm$all_persons_cohort <- copy_to(
  CDMConnector::cdmCon(cdm),
  all_persons_cohort,
  name = "all_persons_cohort",
  temporary = FALSE,
  overwrite = TRUE,
  schema = "cdm_results"
)

# Load variables
cohortName <- "all_persons_cohort"
validdrugs <- loadDrugs()
regGroups <- loadGroups()

## Make breast cancer regimens
regimens <- loadRegimens(condition = "all")
regimens <- regimens |> 
    dplyr::filter(grepl("breast", tolower(condition)))
# Add D-AC+Bev variant corresponding to test patient
new <- filter(regimens, regCode == "56896")[1,]
new$variant <- "Variant #02"
new$regString <- "21.bevacizumab;0.docetaxel;21.bevacizumab;0.docetaxel;21.bevacizumab;0.docetaxel;21.bevacizumab;0.docetaxel;21.bevacizumab;0.cyclophosphamide;0.doxorubicin;21.bevacizumab;0.cyclophosphamide;0.doxorubicin;21.cyclophosphamide;0.doxorubicin;"
new$shortString <- new$regString
regimens <- dplyr::bind_rows(regimens, new)

##
con_df <- cdm$drug_exposure |> 
    dplyr::inner_join(
      cdm[[cohortName]],
      by = c("person_id" = "person_id")
    ) |> 
    dplyr::left_join(
      cdm$concept_ancestor,
      by = c("drug_concept_id" = "descendant_concept_id")
    ) |> 
    dplyr::left_join(
      cdm$concept,
      by = c("ancestor_concept_id" = "concept_id")
    ) |> 
    dplyr::filter(
      tolower(concept_class_id) == "ingredient"
    ) |> 
    dplyr::transmute(
      person_id,
      cohort_start_date,
      cohort_end_date,
      drug_exposure_start_date,
      drug_concept_id,
      ancestor_concept_id,
      concept_name
    ) |>
    dplyr::collect()

  con_df <- con_df |>
    dplyr::mutate(
      person_id = as.character(person_id),
      cohort_start_date = normalize_date(cohort_start_date),
      cohort_end_date = normalize_date(cohort_end_date),
      drug_exposure_start_date = normalize_date(drug_exposure_start_date)
    ) |>
    dplyr::mutate(
      drug_exposure_day_relative = as.numeric(drug_exposure_start_date - cohort_start_date)
    )


##


# Prepare a data.frame of patient drug records used in the alignment step
stringDF <- stringDF_from_cdm(con_df = con_df,
                              validDrugs = validdrugs)

## Alignment
output_all <- stringDF %>%
    generateRawAlignments(
        regimens = regimens,
        g = 0.4,
        Tfac = 0.4,
        method = "PropDiff",
        verbose = 0
    )


## Post-process Alignment
processedAll <- output_all %>%
    processAlignments(regimens = regimens, 
                      regimenCombine = 28)

pa <- processedAll %>% 
    calculateEras()

## Data analysis
## Plot alignments for every patient 

p <- plotAlignment(pa)
# check graphs
p
