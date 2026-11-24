test_that("montages can be placed in tidylayouts layouts", {
  skip_if_not_installed("tidylayouts")
  skip_if_not(exists("as_layout_gtable", asNamespace("tidylayouts")))
  images <- local_montage_images()
  m <- tidymontage(images) |>
    adjust_layout(x = condition, y = channel) |>
    add_color_legend("bottom")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())

  # the panel track is the image grid; headers and legend are decoration
  gt <- tidylayouts::as_layout_gtable(m)
  grid_mm <- montage_layout_space(m)$panels
  widths <- grid::convertWidth(gt$widths, "mm", valueOnly = TRUE)
  heights <- grid::convertHeight(gt$heights, "mm", valueOnly = TRUE)
  expect_equal(widths[2], max(grid_mm$xmax) - min(grid_mm$xmin))
  expect_equal(heights[2], max(grid_mm$ymax) - min(grid_mm$ymin))
  expect_gt(heights[1], 0) # column headers above
  expect_gt(heights[3], 0) # legend below

  layout <- tidylayouts::new_row(tidylayouts::dummy(), m) |>
    tidylayouts::layout_tags("A")
  sol <- tidylayouts:::prepare_layout(layout)
  leaf <- tidylayouts:::layout_leaves(sol$node)[[2]]
  expect_equal(leaf$meas$x$span, widths[2])
  expect_equal(leaf$meas$y$span, heights[2])
  # the montage's image grid and the dummy's panel share their bottom edge
  bottom <- function(p) p$y$start + p$y$span
  ids <- vapply(tidylayouts:::layout_leaves(sol$node), `[[`, character(1), "id")
  expect_equal(bottom(sol$placement[[ids[1]]]), bottom(sol$placement[[ids[2]]]))

  path <- withr::local_tempfile(fileext = ".pdf")
  expect_no_error(tidylayouts::save_layout(layout, path))
  expect_true(file.exists(path))
})
