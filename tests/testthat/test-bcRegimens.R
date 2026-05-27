#------- Unit tests createCancerCohorts with LLM generated test patients -------#

testthat::test_that("PatientGenerator creates a correct set of test patients", {

  patientGenerator <- PatientGenerator::patientChat$new(
    model = "gpt-5.5"
  )
  
  # prompt <- readLines("tests/testthat/prompt-bcRegimens.txt")
  # prompt <- paste(prompt, collapse = "\n")
  
  # patientGenerator$prompt(prompt)
  
  # patientGenerator$save(
  #   name = "testBreastCancerRegimens"
  # )

  cdm <- TestGenerator::patientsCDM(
    testName = "testBreastCancerRegimens",
    cdmVersion = "5.4"
  )

  # create breast cancer cohort
  bc_cohort <- CDMConnector::readCohortSet(
    path = system.file("cohorts", "femaleOnly_breastCancer.json", package = "ARTEMIS")
  )

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
    expect_in(c(
      "Male",
      "Female")
    )
  
  # test number patients with drug record - should be 3
  cdm$drug_exposure |> 
    dplyr::distinct(person_id) |> 
    dplyr::collect()
    dplyr::nrow()
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

  # check all drug exposures are in the list 
  drug_concept_ids |> 
    unlist() |> 
    unname() %in% 
    (cdm$drug_exposure |> (drug_concept_id)) 
    

  expect_true(all(
    unname(unlist(drug_concept_ids)) %in% dplyr::pull(dplyr::select(cdm$drug_exposure, drug_concept_id))
  ))
  
  # test drug record contains correct regimen drug exposures
  ## Patient 1: 0.cyclophosphamide;0.doxorubicin;0.paclitaxel;
  ## Patient 2: 0.carboplatin;0.cyclophosphamide;0.epirubicin;0.paclitaxel;0.pembrolizumab;7.carboplatin;0.paclitaxel;7.carboplatin;0.paclitaxel;
  ## Patient 3: 0.cyclophosphamide;0.docetaxel;


})