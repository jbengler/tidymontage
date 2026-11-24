test_that("tidymontage_options() sets the defaults of new montages", {
  withr::local_options(tidymontage.width = NULL, tidymontage.height = NULL,
                       tidymontage.units = NULL, tidymontage.gap = NULL)
  images <- example_images()
  expect_equal(tidymontage(images)$setup$size$width, 90)

  old <- tidymontage_options(width = 140, height = 120, gap = 2)
  expect_null(old$tidymontage.width)
  m <- tidymontage(images)
  expect_equal(c(m$setup$size$width, m$setup$size$height), c(140, 120))
  expect_equal(m$setup$gap, 2)
  # the recipe shows the size
  expect_match(format(m)[2], "width = 140, height = 120")

  # arguments win; adjust_size() falls back to the options too
  expect_equal(tidymontage(images, width = 50)$setup$size$width, 50)
  expect_equal(tidymontage(images, width = 50)$setup$size$height, 120)
  s <- adjust_size(m, width = 60)$steps[[1]]$params
  expect_equal(c(s$width, s$height), c(60, 120))

  # units apply to the option values
  tidymontage_options(width = 10, height = NA, units = "cm")
  m <- tidymontage(images)
  expect_equal(m$setup$size$width, 100)
  expect_true(is.na(m$setup$size$height))

  # without arguments: back to the package defaults
  tidymontage_options()
  m <- tidymontage(images)
  expect_equal(c(m$setup$size$width, m$setup$size$height, m$setup$gap), c(90, 90, 1))
})

test_that("tidymontage_options() validates", {
  withr::local_options(tidymontage.width = NULL, tidymontage.height = NULL,
                       tidymontage.units = NULL, tidymontage.gap = NULL)
  expect_error(tidymontage_options(width = -1), "positive number")
  expect_error(tidymontage_options(width = NA, height = NA), "At least one")
  expect_error(tidymontage_options(units = "px"))
  expect_error(tidymontage_options(gap = -1))
  expect_null(getOption("tidymontage.width"))
})
