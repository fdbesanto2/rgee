context("rgee: ee_remove_credentials test")

test_that("ee_remove_credentials",{
  result_True <- ee_remove_credentials('test')
  expect_true(result_True)
})

test_that("ee_remove_credentials not-defined",{
  result_True <- ee_clean_pyenv()
  expect_true(result_True)
})
