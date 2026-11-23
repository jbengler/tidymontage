test_that("tidymontage() starts a montage without steps", {
  m <- tidymontage(example_images())
  expect_s3_class(m, "tidymontage")
  expect_true(is_tidymontage(m))
  expect_named(m, c("images", "setup", "steps"))
  expect_s3_class(m$images, "tbl_df")
  expect_equal(m$steps, list())
})

test_that("tidymontage() accepts plain data frames", {
  m <- tidymontage(as.data.frame(example_images()))
  expect_s3_class(m$images, "tbl_df")
})

test_that("tidymontage() validates its inputs", {
  expect_snapshot(error = TRUE, {
    tidymontage("not a data frame")
    tidymontage(example_images()[, "filepath"])
    tidymontage(transform(example_images(), img = 1:4))
    tidymontage(dplyr::mutate(example_images(), filepath = 1:4))
    tidymontage(dplyr::mutate(example_images(), view = "a"))
  })
})

test_that("is_tidymontage() is FALSE for other objects", {
  expect_false(is_tidymontage(example_images()))
  expect_false(is_tidymontage(NULL))
})
