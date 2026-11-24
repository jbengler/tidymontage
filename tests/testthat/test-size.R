grid_size <- function(p) {
  c(width = max(p$xmax) - min(p$xmin), height = max(p$ymax) - min(p$ymin))
}

test_that("the panel grid fits into 90 x 90 mm by default", {
  # 4 x 5 px panels (aspect 0.8), 2 columns x 2 rows, 1 mm gaps: width-limited
  p <- get_panels(adjust_layout(tidymontage(example_images()), x = condition, y = channel))
  s <- grid_size(p)
  expect_equal(s[["width"]], 90)
  expect_equal(s[["height"]], 2 * (89 / 2) * 0.8 + 1)
  # headers sit outside the box
  expect_equal(min(p$xmin), strip_mm(7))
  expect_equal(min(p$ymin), strip_mm(7))
})

test_that("the limiting side depends on the layout", {
  images <- vctrs::vec_rbind(example_images(), example_images())
  images$condition <- rep(c("a", "b", "c", "d"), each = 2)
  # 1 column x 8 rows: height-limited
  p <- get_panels(adjust_layout(tidymontage(images), y = c(condition, channel)))
  s <- grid_size(p)
  expect_equal(s[["height"]], 90)
  expect_lt(s[["width"]], 90)
})

test_that("adjust_size() sets the box, in any unit, with one side free", {
  m <- tidymontage(example_images()) |> adjust_layout(x = condition, y = channel)
  expect_equal(grid_size(get_panels(adjust_size(m, 180, 30)))[["height"]], 30)
  expect_equal(grid_size(get_panels(adjust_size(m, 18, NA, units = "cm")))[["width"]], 180)
  expect_equal(grid_size(get_panels(adjust_size(m, NA, 2, units = "in")))[["height"]], 50.8)
})

test_that("adjust_size() validates and prints", {
  m <- tidymontage(example_images())
  expect_error(adjust_size(m, -1), "positive number")
  expect_error(adjust_size(m, NA, NA), "At least one")
  expect_error(adjust_size(m, units = "pt"))
  expect_equal(format(adjust_size(m, 180, NA)$steps[[1]]), "adjust_size(width = 180, height = NA)")
  expect_equal(format(adjust_size(m, 8, 6, "cm")$steps[[1]]), 'adjust_size(width = 8, height = 6, units = "cm")')
})

test_that("too many panels for the box are refused", {
  m <- tidymontage(example_images()) |> adjust_layout(x = condition, y = channel, gap = 10) |>
    adjust_size(width = 5, height = NA)
  expect_error(get_panels(m), "too small")
})

test_that("the montage gtable has the physical size, with the image grid as panel", {
  m <- adjust_layout(tidymontage(local_montage_images()), x = condition, y = channel)
  gt <- montage_gtable(m)
  expect_s3_class(gt, "gtable")
  expect_equal(gtable_size_mm(gt)[["width"]], 90 + strip_mm(7))
  widths <- as.numeric(gt$widths)
  heights <- as.numeric(gt$heights)
  # lead: row headers, span: the image grid, trail: nothing
  expect_equal(widths, c(strip_mm(7), 90, 0))
  expect_equal(heights[1], strip_mm(7))
  panel <- gt$layout[gt$layout$name == "panel", ]
  expect_equal(c(panel$t, panel$l), c(2, 2))
})
