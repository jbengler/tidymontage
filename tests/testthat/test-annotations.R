# local_montage_images(): 10 x 8 px images with 0.1 um pixels, i.e. 1 um wide.

build_space <- function(m) {
  montage_layout_space(adjust_size(m, width = 100, height = NA), call = NULL)
}

test_that("nice_length() picks 1, 2 or 5 times a power of ten", {
  expect_equal(nice_length(100), 20)
  expect_equal(nice_length(60), 10)
  expect_equal(nice_length(30), 5)
  expect_equal(nice_length(1), 0.2)
  expect_equal(nice_length(15), 2)
})

test_that("one scale bar per view, in the bottom-right panel", {
  m <- tidymontage(local_montage_images()) |> adjust_layout(x = condition, y = channel) |>
    add_scale_bar()
  s <- build_space(m)
  expect_equal(nrow(s$scale_bars), 1)
  last <- s$panels[s$panels$row == 2 & s$panels$col == 2, ]
  w <- last$xmax - last$xmin
  # images are 1 um wide: auto length 0.2 um = a fifth of the panel
  expect_equal(s$scale_bars$xmax - s$scale_bars$xmin, 0.2 * w)
  expect_equal(s$scale_bars$xmax, last$xmax - 1.5)
  expect_equal(s$scale_bars$ymax, last$ymax - 1.5)
  expect_equal(s$scale_bars$label, "0.2~mu*m")
})

test_that("scale bar lengths can be set per view", {
  m <- tidymontage(local_montage_images()) |>
    add_crop(width = 0.6) |>
    add_zoom(width = 0.3) |> adjust_layout(x = c(view, condition), y = channel)
  s <- build_space(add_scale_bar(m, c(crop = 0.2, zoom = 0.1)))
  expect_equal(nrow(s$scale_bars), 2)
  w <- s$panels$xmax[1] - s$panels$xmin[1]
  expect_equal(s$scale_bars$xmax - s$scale_bars$xmin, c(0.2 / 0.6 * w, 0.1 / 0.3 * w))

  expect_error(build_space(add_scale_bar(m, c(crop = 0.2))), "no value for the view \"zoom\"")
  expect_error(build_space(add_scale_bar(m, 1)), "doesn't fit")
  expect_equal(nrow(build_space(add_scale_bar(m, 0.1, where = "all"))$scale_bars), 8)
})

test_that("scale bars go on merges, in any corner", {
  m <- tidymontage(local_montage_images()) |>
    add_merge(C1, C2) |> adjust_layout(x = condition, y = channel)
  s <- build_space(add_scale_bar(m, 0.2, where = "merge", position = "topleft"))
  merges <- s$panels[s$panels$.is_merge, ]
  expect_equal(nrow(s$scale_bars), 2)
  expect_equal(s$scale_bars$xmin, merges$xmin + 1.5)
  expect_equal(s$scale_bars$ymin, merges$ymin + 1.5)
  expect_equal(unique(s$scale_bars$label_vjust), 1)

  expect_warning(
    build_space(add_scale_bar(adjust_layout(tidymontage(local_montage_images()), x = condition, y = channel), where = "merge")),
    "No panels match"
  )
})

test_that("scale bars need a pixel size and follow different magnifications", {
  expect_error(
    build_space(add_scale_bar(adjust_layout(tidymontage(example_images()), x = condition, y = channel))),
    "need a known pixel size"
  )

  images <- local_montage_images()
  recs <- vctrs::vec_data(images$img)
  for (i in which(images$condition == "ko")) recs[[i]]$node$pixel_size <- 0.2
  images$img <- new_img(recs)
  m <- tidymontage(images) |> adjust_layout(x = condition, y = channel) |> add_scale_bar(0.2)
  expect_message(s <- build_space(m), "different magnifications")
  expect_equal(nrow(s$scale_bars), 4)
  bar_w <- s$scale_bars$xmax - s$scale_bars$xmin
  expect_equal(bar_w[2], bar_w[1] / 2)
})

test_that("headers nest when several dimensions share an axis", {
  m <- tidymontage(local_montage_images()) |>
    add_crop(width = 0.6) |>
    add_zoom(width = 0.3) |> adjust_layout(x = c(view, condition), y = channel)
  s <- build_space(m)
  top <- s$labels[s$labels$angle == 0, ]
  expect_equal(top$label, c("crop", "zoom", "ctrl", "ko", "ctrl", "ko"))
  # outer headers span two columns, with a line underneath
  p <- s$panels
  expect_equal(top$x[1], (min(p$xmin[p$col == 1]) + max(p$xmax[p$col == 2])) / 2)
  expect_equal(nrow(s$lines), 2)
  expect_equal(min(p$ymin), 2 * strip_mm(7))

  s <- build_space(adjust_headers(m, x = FALSE, size = 9))
  expect_equal(unique(s$labels$angle), 90)
  expect_equal(min(s$panels$ymin), 0)
  expect_equal(min(s$panels$xmin), strip_mm(9))
})

test_that("annotation verbs validate their arguments", {
  m <- tidymontage(example_images())
  expect_snapshot(error = TRUE, {
    add_scale_bar(m, -1)
    add_scale_bar(m, c(1, 2))
    add_scale_bar(m, where = "first")
    add_scale_bar(m, color = "notacolour")
    add_scale_bar(m, outline = "notacolour")
    adjust_headers(m, size = 0)
  })
})

test_that("annotation steps print only non-default arguments", {
  m <- tidymontage(example_images()) |>
    add_scale_bar() |>
    add_scale_bar(c(crop = 10, zoom = 2), where = "merge") |>
    add_scale_bar(outline = NA) |>
    adjust_headers(y = FALSE)
  expect_equal(
    vapply(m$steps, format, character(1)),
    c(
      "add_scale_bar()",
      'add_scale_bar(c(crop = 10, zoom = 2), where = "merge")',
      "add_scale_bar(outline = NA)",
      "adjust_headers(y = FALSE)"
    )
  )
})

test_that("scale bars have an outline and a halo unless switched off", {
  m <- tidymontage(local_montage_images()) |> adjust_layout(x = condition, y = channel)
  with_outline <- montage_elements(add_scale_bar(m))
  without <- montage_elements(add_scale_bar(m, outline = NA))
  # 12 halo copies of the label
  expect_equal(sum(grepl("^scale-bar-label-1-halo-", names(with_outline))), 12)
  expect_equal(sum(grepl("-halo-", names(without))), 0)
  expect_equal(with_outline[["scale-bars"]]$gp$col, "black")
  expect_true(is.na(without[["scale-bars"]]$gp$col))
})

test_that("annotated montages render consistently", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  m <- tidymontage(local_montage_images()) |>
    adjust_exposure(min = 0, max = "p100") |>
    add_merge(C1, C2) |>
    add_crop(width = 0.6) |>
    add_zoom(width = 0.3) |> adjust_layout(x = c(view, condition), y = channel) |>
    add_scale_bar()
  vdiffr::expect_doppelganger("annotated montage", drawing(m))
})
