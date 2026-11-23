test_that("range specs are percentiles or values", {
  expect_equal(parse_range_spec("p99.9", "max"), list(type = "percentile", value = 99.9))
  expect_equal(parse_range_spec(4000, "max"), list(type = "value", value = 4000))
  expect_equal(parse_range_spec("4000", "max"), list(type = "value", value = 4000))
  expect_error(parse_range_spec("99%", "max"), "must be a percentile")
  expect_error(parse_range_spec("p101", "max"), "must be a percentile")
  expect_error(parse_range_spec(c(1, 2), "max"), "must be a percentile")
})

ranges_for <- function(exposure, images = example_images(), pixels = NULL) {
  panels <- tibble::tibble(.image = seq_len(nrow(images)), channel = images$channel, view = "full")
  pixels <- pixels %||% list(
    matrix(0:99, 10), matrix(0:99 + 1000, 10), # ctrl: DAPI, GFP
    matrix(0:99 * 2, 10), matrix(0:99 + 5000, 10) # ko: DAPI, GFP
  )
  montage_ranges(panels, images, pixels, exposure)
}

test_that("display ranges are linked per channel by default", {
  r <- ranges_for(default_exposure() |> utils::modifyList(list(
    min = list(type = "value", value = 0),
    max = list(type = "percentile", value = 100)
  )))
  # DAPI: max over ctrl (99) and ko (198); GFP: max over 1099 and 5099
  expect_equal(r$hi, c(198, 5099, 198, 5099))
  expect_equal(r$lo, c(0, 0, 0, 0))
})

test_that(".by unlinks on purpose, overrides and columns take precedence", {
  ex <- default_exposure()
  ex$max <- list(type = "percentile", value = 100)
  ex$by <- c("channel", "condition")
  expect_equal(ranges_for(ex)$hi, c(99, 1099, 198, 5099))

  ex$overrides <- list(GFP = list(min = list(type = "value", value = 10), max = list(type = "value", value = 20)))
  r <- ranges_for(ex)
  expect_equal(r$lo[c(2, 4)], c(10, 10))
  expect_equal(r$hi[c(2, 4)], c(20, 20))

  images <- example_images()
  images$display_max <- c(NA, NA, 7, NA)
  expect_equal(ranges_for(ex, images)$hi[3], 7)
})

test_that("a range spanning channels warns, flat ranges are widened", {
  ex <- default_exposure()
  ex$by <- "condition"
  expect_warning(ranges_for(ex), "shared by several channels")

  flat <- rep(list(matrix(5L, 2, 2)), 4)
  r <- ranges_for(default_exposure(), pixels = flat)
  expect_true(all(r$hi > r$lo))
})

test_that("adjust_exposure() validates its arguments", {
  m <- tidymontage(example_images())
  expect_error(adjust_exposure(m, RFP = c(0, 1)), "Unknown channel")
  expect_error(adjust_exposure(m, DAPI = 5), "two values")
  expect_error(adjust_exposure(m, max = "high"), "must be a percentile")
  expect_error(adjust_exposure(m, .by = genotype), "Can't find")
})

test_that("adjust_colors() validates its arguments", {
  m <- tidymontage(example_images())
  expect_error(adjust_colors(m, RFP = "red"), "Unknown channel")
  expect_error(adjust_colors(m, DAPI = "notacolour"), "valid colour")
  expect_error(adjust_colors(m, "red"), "must be named")
})
