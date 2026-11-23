test_that("tidymontage() builds a recipe without steps", {
  m <- tidymontage(example_images(), x = condition)

  expect_s3_class(m, "tidymontage")
  expect_true(is_tidymontage(m))
  expect_named(m, c("images", "mapping", "layout", "steps"))
  expect_s3_class(m$images, "tbl_df")
  expect_equal(rlang::as_label(m$mapping$x), "condition")
  expect_true(rlang::quo_is_null(m$mapping$y))
  expect_null(m$layout)
  expect_equal(m$steps, list())
})

test_that("tidymontage() accepts plain data frames", {
  m <- tidymontage(as.data.frame(example_images()))
  expect_s3_class(m$images, "tbl_df")
})

test_that("tidymontage() accepts expressions in x and y", {
  m <- tidymontage(example_images(), x = toupper(condition), y = "row")
  expect_equal(rlang::as_label(m$mapping$x), "toupper(condition)")
})

test_that("tidymontage() validates its inputs", {
  expect_snapshot(error = TRUE, {
    tidymontage("not a data frame")
    tidymontage(example_images()[, "filepath"])
    tidymontage(transform(example_images(), img = 1:4))
    tidymontage(dplyr::mutate(example_images(), filepath = 1:4))
    tidymontage(example_images(), x = genotype)
    tidymontage(example_images(), x = 1:3)
    tidymontage(example_images(), layout = "grid")
  })
})

test_that("is_tidymontage() is FALSE for other objects", {
  expect_false(is_tidymontage(example_images()))
  expect_false(is_tidymontage(NULL))
})
