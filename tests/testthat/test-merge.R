test_that("add_merge() validates its arguments", {
  m <- tidymontage(example_images())
  expect_snapshot(error = TRUE, {
    add_merge(m, DAPI)
    add_merge(m, DAPI, RFP)
    add_merge(m, DAPI, GFP, name = "DAPI")
    add_merge(add_merge(m, DAPI, GFP), DAPI, GFP)
    add_merge(m, DAPI, GFP, name = "")
    add_merge(m, DAPI, 1 + 1)
  })
})

test_that("merges print as calls", {
  m <- tidymontage(example_images()) |> add_merge(DAPI, "GFP", name = "both")
  expect_equal(format(m$steps[[1]]), 'add_merge(DAPI, GFP, name = "both")')
  images <- example_images()
  images$channel[images$channel == "GFP"] <- "Alexa Fluor 488"
  m <- tidymontage(images) |> add_merge(DAPI, `Alexa Fluor 488`)
  expect_equal(format(m$steps[[1]]), 'add_merge(DAPI, `Alexa Fluor 488`, name = "merge")')
})

test_that("a merge is a virtual channel in the layout", {
  p <- tidymontage(example_images()) |>
    add_merge(DAPI, GFP) |> adjust_layout(x = channel, y = condition) |>
    montage_panels()
  expect_equal(p$channel, rep(c("DAPI", "GFP", "merge"), 2))
  expect_equal(p$merge, rep(c(FALSE, FALSE, TRUE), 2))
  expect_equal(p$condition, rep(c("ctrl", "ko"), each = 3))
  expect_equal(p$col, rep(1:3, 2))
})

test_that("merge members don't need their own panels", {
  p <- tidymontage(example_images()) |>
    add_merge(DAPI, GFP) |> adjust_layout(x = condition, channel = "merge") |>
    montage_panels()
  expect_equal(p$channel, c("merge", "merge"))
  expect_equal(p$condition, c("ctrl", "ko"))
})

test_that("merges follow columns that are determined by the channel", {
  images <- example_images()
  images$target <- ifelse(images$channel == "DAPI", "nuclei", "protein")
  images$target <- factor(images$target, levels = c("protein", "nuclei"))
  p <- tidymontage(images) |>
    add_merge(DAPI, GFP, name = "overlay") |> adjust_layout(x = condition, y = target) |>
    montage_panels()
  expect_equal(as.character(p$target), rep(c("protein", "nuclei", "overlay"), each = 2))
})

test_that("merges need one image of each member per panel", {
  m <- tidymontage(example_images()) |> add_merge(DAPI, GFP)
  expect_snapshot(error = TRUE, {
    montage_panels(adjust_layout(m, x = channel))
    montage_panels(adjust_layout(m, x = channel, y = condition, condition = "ko") |>
      (\(x) {x$images <- x$images[-4, ]; x})())
  })
})

test_that("merges blend tinted channels additively, with linked ranges", {
  images <- local_montage_images()
  m <- tidymontage(images) |>
    adjust_colors(C1 = "#FF0000", C2 = "#0000FF") |>
    adjust_exposure(min = 0, max = 200, C2 = c(1000, 1200)) |>
    add_merge(C1, C2) |> adjust_layout(x = channel, y = condition)
  b <- montage_build(m, dpi = 72)

  expect_equal(b$panels$channel, rep(c("C1", "C2", "merge"), 2))
  expect_true(all(is.na(b$panels$color[b$panels$.is_merge])))

  unpack <- function(r) {
    v <- as.numeric(unclass(r)) + 2^32 * (unclass(r) < 0)
    matrix(sprintf("#%02X%02X%02X", v %% 256, (v %/% 256) %% 256, (v %/% 65536) %% 256), nrow(r), byrow = TRUE)
  }
  merge_ctrl <- unpack(b$rasters[[3]])
  # ctrl pixel (1, 1): C1 = 0 -> red 0; C2 = 1000 -> blue 0
  expect_equal(merge_ctrl[1, 1], "#000000")
  # ctrl pixel (8, 10) = value 79: red 79/200, blue 79/200
  expect_equal(merge_ctrl[8, 10], sprintf("#%02X00%02X", round(79 / 200 * 255), round(79 / 200 * 255)))
  # the merge equals the sum of its single-channel panels
  red <- unpack(b$rasters[[1]])
  blue <- unpack(b$rasters[[2]])
  expect_equal(substr(merge_ctrl, 2, 3), substr(red, 2, 3))
  expect_equal(substr(merge_ctrl, 6, 7), substr(blue, 6, 7))
})

test_that("merged colours are clipped, not wrapped", {
  rgb <- blend_rgb(list(list(matrix(200), matrix(0), matrix(0)), list(matrix(200), matrix(10), matrix(0))))
  r <- pack_raster(rgb)
  v <- as.numeric(unclass(r)) + 2^32 * (unclass(r) < 0)
  expect_equal(c(v %% 256, (v %/% 256) %% 256, (v %/% 65536) %% 256), c(255, 10, 0))
})

test_that("merges render consistently", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  m <- tidymontage(local_montage_images()) |>
    adjust_exposure(min = 0, max = "p100") |>
    add_merge(C1, C2) |> adjust_layout(x = channel, y = condition)
  vdiffr::expect_doppelganger("channels and merge", drawing(m))
})
