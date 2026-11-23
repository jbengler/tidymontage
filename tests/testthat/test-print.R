test_that("print() summarises the recipe", {
  m <- tidymontage(example_images(), x = condition)
  expect_snapshot(print(m))

  m <- add_step(m, new_step("select_planes", list(z = "max", t = 1L)))
  m <- add_step(m, new_step("add_merge"))
  expect_snapshot(print(m))
})

test_that("print() uses singular nouns for one item", {
  m <- tidymontage(example_images()[1, ])
  expect_match(format(m)[1], "1 image from 1 file, 1 channel", fixed = TRUE)
})

test_that("print() returns its input invisibly", {
  m <- tidymontage(example_images())
  expect_output(expect_invisible(out <- print(m)))
  expect_identical(out, m)
})
