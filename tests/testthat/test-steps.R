test_that("add_step() appends steps in order", {
  m <- tidymontage(example_images())
  m <- add_step(m, new_step("select_planes", list(z = "max", t = 1L)))
  m <- add_step(m, new_step("add_merge"))

  expect_length(m$steps, 2)
  expect_equal(vapply(m$steps, `[[`, character(1), "type"), c("select_planes", "add_merge"))
  expect_s3_class(m$steps[[1]], c("tidymontage_step_select_planes", "tidymontage_step"))
  expect_equal(m$steps[[1]]$params, list(z = "max", t = 1L))
})

test_that("steps format as calls", {
  expect_equal(format(new_step("select_planes", list(z = "max", t = 1L))), 'select_planes(z = "max", t = 1L)')
  expect_equal(format(new_step("add_merge")), "add_merge()")
})

test_that("add_step() requires a tidymontage", {
  expect_snapshot(error = TRUE, add_step(example_images(), new_step("add_merge")))
})

test_that("new_step() rejects malformed steps", {
  expect_error(new_step(c("a", "b")), class = "rlang_error")
  expect_error(new_step("a", list(1)), class = "rlang_error")
})
