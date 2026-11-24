# local_montage_images(): C1 = 0..79 (+100 for ko), C2 = 1000 + the same.

test_that("an overlay is a virtual channel next to channels and merges", {
  p <- tidymontage(local_montage_images(), x = condition) |>
    add_merge(C1, C2) |>
    add_overlay(C1, C2, name = "overlap") |>
    get_panels()
  ctrl <- p[p$condition == "ctrl", ]
  expect_equal(ctrl$channel, c("C1", "C2", "merge", "overlap"))
  expect_equal(ctrl$merge, c(FALSE, FALSE, TRUE, FALSE))
  expect_equal(ctrl$overlay, c(FALSE, FALSE, FALSE, TRUE))
})

test_that("the overlay is the minimum of the display-scaled members, in one colour", {
  m <- tidymontage(local_montage_images(), x = condition, channel = "overlap") |>
    adjust_exposure(min = 0, max = 100, C2 = c(1000, 1050)) |>
    add_overlay(C1, C2, name = "overlap", color = "#FF0000")
  b <- montage_build(m, dpi = 72)
  red <- unpack_rgb(b$rasters[[1]])$red
  green <- unpack_rgb(b$rasters[[1]])$green
  # ctrl pixel (r, c) has value (r - 1) * 10 + (c - 1) in both channels:
  # C1 scaled by 100, C2 by 50 -> min is C1's value / 100
  values <- matrix(0:79, 8, 10, byrow = TRUE)
  expected <- round(pmin(values / 100, pmin(values / 50, 1)) * 255)
  expect_equal(red, expected)
  expect_true(all(green == 0))
})

test_that("a threshold hides weak overlap, a black overlay is inverted", {
  images <- local_montage_images()
  m <- tidymontage(images, x = condition, channel = "o") |>
    adjust_exposure(min = 0, max = 79) |>
    add_overlay(C1, C2, name = "o", threshold = 0.5)
  b <- montage_build(m, dpi = 72)
  red <- unpack_rgb(b$rasters[[1]])$red
  expect_equal(red[1, 1:5], rep(0, 5)) # values 0-4 of 79: below the threshold
  expect_gt(red[8, 10], 200)

  m <- tidymontage(images, x = condition, channel = "o") |> add_overlay(C1, C2, name = "o", color = "black")
  expect_equal(unique(get_panels(m)$background), "white")
})

test_that("overlays get a legend entry with their members", {
  m <- tidymontage(local_montage_images(), x = condition) |>
    add_overlay(C1, C2, name = "overlap", color = "yellow") |>
    add_color_legend()
  lg <- montage_layout_space(m, call = NULL)$legend
  expect_equal(lg$label, c("C1", "C2", "overlap (C1, C2)"))
  expect_equal(lg$color[3], "yellow")
})

test_that("a legend wider than the panels widens the figure evenly", {
  images <- local_montage_images()
  m <- tidymontage(images, channel = "a very long overlay name to widen the legend", condition = "ctrl", width = 20, height = NA) |>
    add_overlay(C1, C2, name = "a very long overlay name to widen the legend", color = "yellow")
  without <- montage_layout_space(m, call = NULL)
  with <- montage_layout_space(add_color_legend(m), call = NULL)
  added <- with$width - without$width
  expect_gt(added, 0)
  expect_equal(with$panels$xmin, without$panels$xmin + added / 2)
  expect_true(min(with$legend$xmin) >= 0)
  expect_lte(max(with$legend$text_x + text_width_mm(with$legend$label, 7)), with$width + 1e-6)
})

test_that("overlays don't count as merges for hero, boxes and scale bars", {
  images <- local_montage_images()
  m <- tidymontage(images, x = condition, layout = "hero") |>
    add_merge(C1, C2) |>
    add_overlay(C1, C2, name = "overlap") |>
    add_zoom(width = 0.5, height = 0.4, box = "merge") |>
    add_scale_bar(where = "merge")
  s <- montage_layout_space(m, call = NULL)
  expect_equal(s$panels$channel[s$panels$.role == "hero"], c("merge", "merge"))
  # side panels: zoomed channels; the overlay is not chosen as hero
  expect_false(any(s$panels$channel[s$panels$.role == "hero"] == "overlap"))
  expect_equal(nrow(s$boxes), 2)
})

test_that("add_overlay() validates and prints", {
  m <- tidymontage(local_montage_images())
  expect_snapshot(error = TRUE, {
    add_overlay(m, C1)
    add_overlay(m, C1, C9)
    add_overlay(m, C1, C2, color = "notacolour")
    add_overlay(m, C1, C2, threshold = 2)
    add_overlay(add_merge(m, C1, C2, name = "both"), C1, C2, name = "both")
  })
  expect_equal(format(add_overlay(m, C1, C2)$steps[[1]]), 'add_overlay(C1, C2, name = "overlay")')
  expect_equal(
    format(add_overlay(m, C1, C2, name = "o", color = "yellow", threshold = 0.2)$steps[[1]]),
    'add_overlay(C1, C2, name = "o", color = "yellow", threshold = 0.2)'
  )
})

test_that("overlays render consistently", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  m <- tidymontage(local_montage_images(), x = condition) |>
    adjust_exposure(min = 0, max = "p100") |>
    add_overlay(C1, C2, color = "yellow") |>
    add_color_legend()
  vdiffr::expect_doppelganger("overlay", drawing(m))
})
