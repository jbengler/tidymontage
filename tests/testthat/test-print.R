test_that("format() summarises the steps", {
  m <- tidymontage(example_images())
  expect_snapshot(cat(format(m), sep = "\n"))

  m <- m |>
    adjust_colors(DAPI = "#0072B2") |>
    adjust_exposure(min = 0, max = "p99", GFP = c("p1", 4000), .by = c(channel, condition)) |> adjust_layout(x = condition, y = channel, channel = c("GFP", "DAPI"))
  expect_snapshot(cat(format(m), sep = "\n"))
})

test_that("format() uses singular nouns for one item", {
  m <- tidymontage(example_images()[1, ])
  expect_match(format(m)[1], "1 image from 1 file, 1 channel", fixed = TRUE)
})

test_that("print() draws the montage and returns it invisibly", {
  m <- tidymontage(local_montage_images()) |> adjust_layout(x = condition, y = channel)
  path <- withr::local_tempfile(fileext = ".png")
  grDevices::png(path)
  expect_invisible(out <- print(m))
  grDevices::dev.off()
  expect_identical(out, m)
})
