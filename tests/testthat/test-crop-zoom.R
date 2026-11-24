# local_montage_images(): 8 x 10 px images, pixel size 0.1 um,
# value at (row r, col c) = base + offset + (r - 1) * 10 + (c - 1).

regions <- function(m) {
  p <- get_panels(m)
  p[, c("channel", "view", "condition", "px_xmin", "px_xmax", "px_ymin", "px_ymax")]
}

test_that("crops have one size and positions per image", {
  images <- local_montage_images()
  m <- tidymontage(images) |> adjust_layout(x = condition, y = channel)

  # 0.4 um = 4 px, centered on the image center (5, 4)
  r <- regions(add_crop(m, width = 0.4))
  expect_equal(unique(r$view), "crop")
  expect_equal(unique(r$px_xmin), 4)
  expect_equal(unique(r$px_xmax), 7)
  expect_equal(unique(r$px_ymin), 3)
  expect_equal(unique(r$px_ymax), 6)

  # pixel sizes and pixel centers (0-based, as in Fiji)
  r <- regions(add_crop(m, width = 4, height = 2, units = "px", center = c(2, 2), center_units = "px"))
  expect_equal(unique(r$px_xmin), 1)
  expect_equal(unique(r$px_xmax), 4)
  expect_equal(unique(r$px_ymin), 2)
  expect_equal(unique(r$px_ymax), 3)

  # one center per condition
  centers <- tibble::tibble(condition = c("ctrl", "ko"), x = c(0.3, 0.7), y = 0.5)
  r <- regions(add_crop(m, width = 0.4, center = centers))
  expect_equal(r$px_xmin[r$condition == "ctrl"], c(2, 2))
  expect_equal(r$px_xmin[r$condition == "ko"], c(6, 6))
})

test_that("crops show the right pixels and keep the full-image display range", {
  images <- local_montage_images()
  m <- tidymontage(images) |>
    adjust_colors(C1 = "#FF0000") |>
    add_crop(width = 0.4) |> adjust_layout(x = condition, y = channel)
  b <- montage_build(m, dpi = 72)
  expect_equal(dim(b$rasters[[1]]), c(4, 4))
  # range from the full images: C1 values 0..79 (ctrl) and 100..179 (ko)
  expect_equal(b$panels$display_max[1], stats::quantile(c(0:79, 100:179), 0.999, names = FALSE))

  v <- as.numeric(unclass(b$rasters[[1]])) + 2^32 * (unclass(b$rasters[[1]]) < 0)
  red <- matrix(v %% 256, 4, 4, byrow = TRUE)
  lo <- b$panels$display_min[1]
  hi <- b$panels$display_max[1]
  # top-left of the crop is pixel (row 3, col 4) with value 23
  expect_equal(red[1, 1], round((23 - lo) / (hi - lo) * 255))
})

test_that("regions beyond the image are moved inside with a warning", {
  m <- tidymontage(local_montage_images()) |>
    add_crop(width = 0.4, center = c(0, 1)) |> adjust_layout(x = condition, y = channel)
  expect_warning(r <- regions(m), "moved inside")
  expect_equal(unique(r$px_xmin), 1)
  expect_equal(unique(r$px_ymax), 8)
})

test_that("crop problems are explained", {
  m <- tidymontage(local_montage_images()) |> adjust_layout(x = condition, y = channel)
  expect_error(regions(add_crop(m, width = 2)), "larger than the image")
  centers <- tibble::tibble(condition = "ctrl", x = 0.5, y = 0.5)
  expect_error(regions(add_crop(m, width = 0.4, center = centers)), "No center .* condition = ko")
  centers <- tibble::tibble(condition = c("ctrl", "ctrl", "ko"), x = 0.5, y = 0.5)
  expect_error(regions(add_crop(m, width = 0.4, center = centers)), "More than one center")

  images <- example_images() # fake images without pixel size
  expect_error(
    get_panels(adjust_layout(add_crop(tidymontage(images), width = 1), x = condition, y = channel)),
    "no known pixel size"
  )
})

test_that("add_crop() and add_zoom() validate their arguments", {
  m <- tidymontage(example_images())
  expect_snapshot(error = TRUE, {
    add_crop(m, width = -1)
    add_crop(m, width = 1, center = c(0.5, 2))
    add_crop(m, width = 1, center = 0.5)
    add_crop(m, width = 1, center = data.frame(x = 0.5))
    add_crop(m, width = 1, center = data.frame(genotype = "a", x = 0.5, y = 0.5))
    add_crop(m, width = 1, units = "mm")
    add_zoom(m, width = 1, name = "full")
    add_zoom(add_zoom(m, width = 1, name = "a"), width = 2, name = "a")
    add_zoom(m, width = 1, box = "some")
  })
})

test_that("a second crop replaces the first", {
  m <- tidymontage(local_montage_images()) |>
    add_crop(width = 0.4) |>
    add_crop(width = 0.6) |> adjust_layout(x = condition, y = channel)
  expect_equal(unique(regions(m)$px_xmax - regions(m)$px_xmin), 5)
})

test_that("zooms are views that are placed automatically, mapped or chosen", {
  m <- tidymontage(local_montage_images()) |>
    add_crop(width = 0.6) |>
    add_zoom(width = 0.2, center = c(0.5, 0.5))
  p <- get_panels(adjust_layout(m, x = condition, y = channel))
  expect_equal(p$view[p$row == 1], c("crop", "zoom", "crop", "zoom"))

  p <- get_panels(adjust_layout(m, x = c(condition, view), y = channel))
  expect_equal(p$view[p$row == 1], c("crop", "zoom", "crop", "zoom"))
  zoom <- p[p$view == "zoom", ]
  expect_equal(unique(zoom$px_xmax - zoom$px_xmin), 1)

  p <- get_panels(adjust_layout(m, x = condition, y = channel, view = "zoom"))
  expect_equal(unique(p$view), "zoom")
})

test_that("zoom boxes mark the region on the main panels", {
  images <- local_montage_images()
  space <- function(m) {
    sp <- montage_spec(m)
    montage_layout_space(m, sp, montage_views(sp), call = NULL)
  }
  # the full images are 10 x 8 px, so the zoom needs the same shape: 5 x 4 px
  m <- tidymontage(images) |>
    add_merge(C1, C2) |>
    add_zoom(width = 0.5, height = 0.4, center = c(0.5, 0.5)) |> adjust_layout(x = c(view, condition), y = channel)
  s <- space(m)
  # one box per main panel: 2 conditions x 3 channels
  expect_equal(nrow(s$boxes), 6)
  # zoom region: x 3..7, y 3..6 of a 10 x 8 px image
  p <- s$panels[s$panels$view == "full", ][1, ]
  w <- p$xmax - p$xmin
  h <- p$ymax - p$ymin
  expect_equal(s$boxes$xmin[1], p$xmin + 2 / 10 * w)
  expect_equal(s$boxes$xmax[1], p$xmin + 7 / 10 * w)
  expect_equal(s$boxes$ymin[1], p$ymin + 2 / 8 * h)
  expect_equal(s$boxes$ymax[1], p$ymin + 6 / 8 * h)

  m_merge <- tidymontage(images) |>
    add_merge(C1, C2) |>
    add_zoom(width = 0.5, height = 0.4, box = "merge") |> adjust_layout(x = c(view, condition), y = channel)
  expect_equal(nrow(space(m_merge)$boxes), 2)

  m_none <- tidymontage(images) |>
    add_zoom(width = 0.5, height = 0.4, box = "none") |> adjust_layout(x = c(view, condition), y = channel)
  expect_null(space(m_none)$boxes)
})

test_that("zooms outside the crop get no box, with a warning", {
  m <- tidymontage(local_montage_images()) |>
    add_crop(width = 0.4, center = c(0.3, 0.5)) |>
    add_zoom(width = 0.2, center = c(0.9, 0.5)) |> adjust_layout(x = c(view, condition), y = channel)
  expect_warning(get_panels(m), "lies outside")
})

test_that("crops and zooms must share the panel shape", {
  m <- tidymontage(local_montage_images()) |>
    add_crop(width = 0.6, height = 0.4) |>
    add_zoom(width = 0.2) |> adjust_layout(x = c(view, condition), y = channel)
  expect_error(get_panels(m), "same aspect ratio")
})

test_that("crop and zoom steps print as calls", {
  centers <- tibble::tibble(condition = c("ctrl", "ko"), x = 0.5, y = 0.5)
  m <- tidymontage(example_images()) |>
    add_crop(width = 40, center = centers) |>
    add_zoom(width = 8, height = 6, center = c(10, 20), center_units = "px", units = "px", box = "merge")
  expect_equal(format(m$steps[[1]]), 'add_crop(width = 40, center = <2 centers by condition>, name = "crop")')
  expect_equal(
    format(m$steps[[2]]),
    'add_zoom(width = 8, height = 6, center = c(10, 20), units = "px", center_units = "px", box = "merge")'
  )
})

test_that("crops and zooms render consistently", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  m <- tidymontage(local_montage_images()) |>
    adjust_exposure(min = 0, max = "p100") |>
    add_merge(C1, C2) |>
    add_crop(width = 0.6, center = c(0.4, 0.5)) |>
    add_zoom(width = 0.2, center = c(0.45, 0.5)) |> adjust_layout(x = c(view, condition), y = channel)
  vdiffr::expect_doppelganger("crop and zoom", drawing(m))
})

test_that("several zooms are named and numbered in order", {
  m <- tidymontage(local_montage_images(), x = c(condition, view), channel = "C1") |>
    add_zoom(width = 4, height = 3.2, center = c(0.3, 0.3), units = "px") |>
    add_zoom(width = 4, height = 3.2, center = c(0.7, 0.6), units = "px", box = "none")
  s <- montage_layout_space(m, call = NULL)
  expect_equal(unique(s$panels$view), c("full", "zoom 1", "zoom 2"))
  # numbers in the boxes (only zoom 1 has boxes) and in the zoom panels
  expect_equal(unique(s$boxes$label), "1")
  zl <- s$zoom_labels
  expect_equal(zl$label, ifelse(s$panels$view[s$panels$view != "full"] == "zoom 1", "1", "2"))
  zp <- s$panels[s$panels$view != "full", ]
  expect_equal(c(zl$x, zl$y), c(zp$xmin, zp$ymin))
  el <- montage_elements(m)
  expect_true(all(c("zoom-box-label-1", "zoom-label-1") %in% names(el)))
  # white text on a black square
  expect_equal(el[["zoom-label-1"]]$gp$col, "white")
  expect_equal(el[["zoom-label-1"]]$gp$fontsize, 7)
  expect_equal(el[["zoom-label-1-square"]]$gp$fill, "black")
  # the box is drawn over the squares in it
  expect_gt(match("zoom-boxes", names(el)), match("zoom-box-label-1", names(el)))

  # one zoom: no number, named "zoom"
  one <- tidymontage(local_montage_images(), x = c(condition, view), channel = "C1") |>
    add_zoom(width = 4, height = 3.2, units = "px")
  s <- montage_layout_space(one, call = NULL)
  expect_null(s$zoom_labels)
  expect_true(all(is.na(s$boxes$label)))
  expect_true("zoom" %in% s$panels$view)
})

test_that("zoom names and labels can be set", {
  m <- tidymontage(local_montage_images(), x = c(condition, view), channel = "C1") |>
    add_zoom(width = 4, height = 3.2, units = "px", name = "spine", label = "a") |>
    add_zoom(width = 4, height = 3.2, center = c(0.7, 0.6), units = "px", label = NA)
  s <- montage_layout_space(m, call = NULL)
  expect_equal(unique(s$panels$view), c("full", "spine", "zoom 2"))
  expect_equal(unique(s$zoom_labels$label), "a")
  expect_equal(sort(unique(s$boxes$label), na.last = TRUE), c("a", NA))
  expect_match(format(m$steps[[1]]), 'name = "spine", label = "a"', fixed = TRUE)
  expect_match(format(m$steps[[2]]), "label = NA", fixed = TRUE)

  expect_error(add_zoom(m, width = 4, label = 1), "single string")
  # an explicit name that the automatic names take
  clash <- tidymontage(local_montage_images()) |>
    add_zoom(width = 4, units = "px", name = "zoom 2") |>
    add_zoom(width = 4, units = "px")
  expect_error(montage_layout_space(clash, call = NULL), "used twice")
})
