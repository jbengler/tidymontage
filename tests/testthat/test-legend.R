legend_space <- function(m) montage_layout_space(m, call = NULL)

test_that("the legend lists the channels shown, with merge members, without merges", {
  m <- tidymontage(local_montage_images(), x = condition, layout = "hero") |>
    adjust_colors(C2 = "#00FFFF") |>
    add_merge(C1, C2) |>
    add_color_legend()
  lg <- legend_space(m)$legend
  expect_equal(lg$label, c("C1", "C2"))
  expect_equal(lg$color, c("#FF00FF", "#00FFFF"))

  # only the merge is shown: its members are still listed
  m <- tidymontage(local_montage_images(), x = condition, channel = "merge") |>
    add_merge(C1, C2) |>
    add_color_legend()
  expect_equal(legend_space(m)$legend$label, c("C1", "C2"))
})

test_that("a legend on top or at the bottom adds height, on the right adds width", {
  m <- tidymontage(local_montage_images(), x = condition)
  base <- legend_space(m)
  top <- legend_space(add_color_legend(m, "top"))
  bottom <- legend_space(add_color_legend(m, "bottom"))
  right <- legend_space(add_color_legend(m, "right"))

  # panels keep their size
  expect_equal(top$panels$xmax - top$panels$xmin, base$panels$xmax - base$panels$xmin)
  expect_equal(right$panels$ymax - right$panels$ymin, base$panels$ymax - base$panels$ymin)

  extra <- top$height - base$height
  expect_gt(extra, 0)
  expect_equal(top$width, base$width)
  expect_equal(top$panels$ymin, base$panels$ymin + extra)
  expect_equal(top$labels$y[top$labels$angle == 0], base$labels$y[base$labels$angle == 0] + extra)
  expect_true(all(top$legend$ymax < min(top$labels$y)))

  expect_equal(bottom$height, base$height + extra)
  expect_equal(bottom$panels$ymin, base$panels$ymin)
  expect_true(all(bottom$legend$ymin > max(bottom$panels$ymax)))

  expect_gt(right$width, base$width)
  expect_equal(right$height, base$height)
  expect_true(all(right$legend$xmin > max(right$panels$xmax)))
  # items stacked vertically on the right, side by side on top
  expect_equal(length(unique(right$legend$xmin)), 1)
  expect_equal(length(unique(top$legend$ymin)), 1)
})

test_that("legend items don't overlap", {
  images <- local_montage_images()
  images$channel[images$channel == "C1"] <- "a much longer channel name"
  lg <- legend_space(add_color_legend(tidymontage(images, x = condition)))$legend
  expect_lt(lg$text_x[1] + text_width_mm(lg$label[1], 7), lg$xmin[2])
})

test_that("add_color_legend() validates and prints", {
  m <- tidymontage(example_images())
  expect_error(add_color_legend(m, "left"))
  expect_error(add_color_legend(m, size = 0), "positive number")
  expect_equal(format(add_color_legend(m)$steps[[1]]), "add_color_legend()")
  expect_equal(format(add_color_legend(m, "right", size = 8)$steps[[1]]), 'add_color_legend(position = "right", size = 8)')
})

test_that("text widths are measured without leaving a device open", {
  n <- length(grDevices::dev.list())
  w <- text_width_mm(c("DAPI", "Alexa Fluor 488"), 7)
  expect_length(grDevices::dev.list(), n)
  expect_true(w[2] > 2 * w[1])
})

test_that("legends render consistently", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  m <- tidymontage(local_montage_images(), x = condition, layout = "hero") |>
    adjust_exposure(min = 0, max = "p100") |>
    add_merge(C1, C2) |>
    add_color_legend("bottom")
  vdiffr::expect_doppelganger("hero with legend", autoplot(m, dpi = 72))
})
