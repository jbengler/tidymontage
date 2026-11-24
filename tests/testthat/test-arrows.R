# local_montage_images(): two conditions x two channels, 10 x 8 pixels.

arrow_space <- function(m) montage_layout_space(m, call = NULL)

test_that("arrowheads are drawn on every panel of an image, at the same place", {
  at <- tibble::tibble(condition = c("ctrl", "ctrl", "ko"), x = c(0.5, 0.2, 0.8), y = c(0.5, 0.25, 0.75))
  m <- tidymontage(local_montage_images(), x = condition) |>
    add_merge(C1, C2) |>
    add_arrows(at)
  s <- arrow_space(m)
  p <- s$panels
  ar <- s$arrows
  # ctrl: two arrows on C1, C2 and the merge; ko: one on each
  expect_equal(as.vector(table(p$condition[ar$panel])), c(6, 3))
  # same relative place in each panel
  rel_x <- (ar$x - p$xmin[ar$panel]) / (p$xmax[ar$panel] - p$xmin[ar$panel])
  rel_y <- (ar$y - p$ymin[ar$panel]) / (p$ymax[ar$panel] - p$ymin[ar$panel])
  ctrl <- p$condition[ar$panel] == "ctrl"
  expect_equal(sort(unique(round(rel_x[ctrl], 6))), c(0.2, 0.5))
  expect_equal(unique(round(rel_x[!ctrl], 6)), 0.8)
  expect_equal(unique(round(rel_y[!ctrl], 6)), 0.75)
  expect_equal(unique(ar$color), "white")
})

test_that("pixel positions, crops and zooms map to the region shown", {
  # pixel (6, 4) of the 10 x 8 image; the crop shows x 3-8, y 2-7 (1-based)
  m <- tidymontage(local_montage_images(), x = condition, channel = "C1") |>
    add_crop(width = 6, height = 6 * 0.8, center = c(5, 4), units = "px", center_units = "px") |>
    add_arrows(c(6, 4), units = "px")
  s <- arrow_space(m)
  p <- s$panels[s$arrows$panel[1], ]
  sx <- (p$xmax - p$xmin) / (p$.x1 - p$.x0 + 1)
  expect_equal(s$arrows$x[1], p$xmin + (6 - (p$.x0 - 1)) * sx)

  # tips outside a zoom are left out there
  m <- tidymontage(local_montage_images(), x = c(condition, view), channel = "C1") |>
    add_zoom(width = 5, height = 4, center = c(0.25, 0.25), units = "px") |>
    add_arrows(c(0.9, 0.9))
  s <- arrow_space(m)
  expect_equal(unique(s$panels$view[s$arrows$panel]), "full")
})

test_that("arrowheads contrast with the panel unless coloured", {
  m <- tidymontage(local_montage_images(), x = condition) |>
    adjust_colors(C1 = "black") |>
    add_arrows(c(0.5, 0.5))
  s <- arrow_space(m)
  expect_equal(
    s$arrows$color,
    ifelse(s$panels$channel[s$arrows$panel] == "C1", "black", "white")
  )
  s <- arrow_space(add_arrows(m, c(0.3, 0.3), color = "yellow", size = 3))
  expect_equal(sum(s$arrows$color == "yellow"), 4)
  expect_equal(unique(s$arrows$size[s$arrows$color == "yellow"]), 3)
})

test_that("arrowheads point up-left from their tip and are drawn clipped", {
  h <- arrowhead_polygon(10, 10, 2)
  expect_equal(c(h$x[1], h$y[1]), c(10, 10))
  expect_true(all(h$x[2:3] > 10 | h$y[2:3] > 10))
  expect_equal(mean(h$x[2:3]) - 10, mean(h$y[2:3]) - 10)

  m <- tidymontage(local_montage_images(), x = condition, channel = "C1") |> add_arrows(c(0.5, 0.5))
  el <- montage_elements(m)
  expect_true(all(c("arrows-1", "arrows-2") %in% names(el)))
  expect_true(isTRUE(el[["arrows-1"]]$vp$clip))
})

test_that("add_arrows() validates and prints", {
  m <- tidymontage(example_images())
  expect_error(add_arrows(m, c(1, 2, 3)), "c\\(x, y\\)")
  expect_error(add_arrows(m, c(2, 0.5)), "between 0 and 1")
  expect_error(add_arrows(m, data.frame(x = 0.5)), "numeric columns")
  expect_error(add_arrows(m, data.frame(sample = "a", x = 0.5, y = 0.5)), "not in the images tibble")
  expect_error(add_arrows(m, c(0.5, 0.5), size = 0), "positive number")
  expect_error(add_arrows(m, c(0.5, 0.5), color = "nope"), "valid colour")

  expect_equal(format(add_arrows(m, c(0.5, 0.5))$steps[[1]]), "add_arrows(at = c(0.5, 0.5))")
  at <- data.frame(condition = c("ctrl", "ko"), x = 0.5, y = 0.5)
  expect_equal(
    format(add_arrows(m, at, size = 3, color = "red")$steps[[1]]),
    "add_arrows(at = <2 positions by condition>, size = 3, color = \"red\")"
  )
  # several rows without keys: arrows on every image
  expect_silent(add_arrows(m, data.frame(x = c(0.2, 0.8), y = c(0.2, 0.8))))
})
