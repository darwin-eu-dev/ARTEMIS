#------- Unit tests for breast cancer regimen test patients -------#

testthat::test_that("breast cancer test patients have the expected structure", {
  testthat::skip_if_not_installed("TestGenerator")
  testthat::skip_if_not_installed("CDMConnector")
  testthat::skip_if_not_installed("CohortConstructor")
  testthat::skip_if_not_installed("PatientProfiles")

  bc_cohort_path <- system.file("cohorts", "femaleOnly_breastCancer.json", package = "ARTEMIS")
  testthat::skip_if(!nzchar(bc_cohort_path),
                    "femaleOnly_breastCancer.json cohort definition not available")

  cdm <- TestGenerator::patientsCDM(
    testName = "testBreastCancerRegimens",
    cdmVersion = "5.4"
  )

  # create breast cancer cohort
  bc_cohort <- CDMConnector::readCohortSet(path = bc_cohort_path)

  cdm <- CDMConnector::generateCohortSet(
      cdm = cdm,
      cohortSet = bc_cohort,
      name = "bc_cohort",
      computeAttrition = TRUE,
      overwrite = TRUE
  )

  # cohort attrition table
  cdm$bc_cohort |>
    CohortConstructor::attrition() |>
    dplyr::select(excluded_records) |>
    sum() |>
    expect_equal(2)

  # test number of patients in cdm instance
  cdm$person |>
    dplyr::collect() |>
    nrow() |>
    expect_equal(6)

  # test valid sex variable
  cdm$person |>
    PatientProfiles::addSex() |>
    dplyr::pull(sex) |>
    unique() |>
    expect_in(c("Male", "Female"))

  # test number patients with drug record - should be 3
  cdm$drug_exposure |>
    dplyr::distinct(person_id) |>
    dplyr::collect() |>
    nrow() |>
    expect_equal(3)

  # test expected drugs are in drug record
  drug_concept_ids <- list(
    cyclophosphamide = 1310317,
    doxorubicin = 1338512,
    paclitaxel = 1378382,
    carboplatin = 1344905,
    epirubicin = 1344354,
    pembrolizumab = 45775965,
    docetaxel = 1315942
  )

  observed_drugs <- cdm$drug_exposure |>
    dplyr::distinct(drug_concept_id) |>
    dplyr::pull(drug_concept_id)

  # check all expected drug exposures are present
  expect_true(all(unname(unlist(drug_concept_ids)) %in% observed_drugs))

  # test drug record contains correct regimen drug exposures
  ## Patient 1: 0.cyclophosphamide;0.doxorubicin;0.paclitaxel;
  ## Patient 2: 0.carboplatin;0.cyclophosphamide;0.epirubicin;0.paclitaxel;0.pembrolizumab;7.carboplatin;0.paclitaxel;7.carboplatin;0.paclitaxel;
  ## Patient 3: 0.cyclophosphamide;0.docetaxel;
})
