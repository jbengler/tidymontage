test_that("bin_mean() averages blocks", {
  m <- matrix(1:16, 4, 4)
  expect_equal(bin_mean(m, 1), m)
  expect_equal(bin_mean(m, 2), matrix(c(mean(c(1, 2, 5, 6)), mean(c(3, 4, 7, 8)), mean(c(9, 10, 13, 14)), mean(c(11, 12, 15, 16))), 2, 2))
  expect_equal(dim(bin_mean(matrix(0, 5, 7), 2)), c(2, 3))
})

test_that("tint_raster() maps the display range onto the colour", {
  m <- matrix(c(0, 50, 100, 200), 2, 2)
  r <- tint_raster(m, lo = 0, hi = 100, color = "#FF8000")
  expect_s3_class(r, "nativeRaster")
  # unpack: nativeRaster stores packed ABGR integers row by row
  v <- as.numeric(unclass(r)) + 2^32 * (unclass(r) < 0)
  hex <- sprintf("#%02X%02X%02X", v %% 256, (v %/% 256) %% 256, (v %/% 65536) %% 256)
  px <- matrix(hex, 2, 2, byrow = TRUE)
  expect_equal(px[1, 1], "#000000")
  expect_equal(px[2, 1], "#804000")
  expect_equal(px[1, 2], "#FF8000")
  expect_equal(px[2, 2], "#FF8000") # clipped at max
})

test_that("montage_build() reads pixels, links ranges and tints", {
  images <- local_montage_images()
  m <- tidymontage(images) |> adjust_layout(x = condition, y = channel)
  b <- montage_build(m, dpi = 72)

  expect_equal(nrow(b$panels), 4)
  # linked per channel: channel 1 spans 0..179 over both conditions
  expect_equal(b$panels$display_min[b$panels$channel == "C1"], rep(stats::quantile(c(0:79, 100:179), 0.001, names = FALSE), 2))
  expect_equal(b$panels$color, c("#FF00FF", "#FF00FF", "#00FF00", "#00FF00"))
  expect_true(all(vapply(b$rasters, inherits, logical(1), "nativeRaster")))
  expect_equal(dim(b$rasters[[1]]), c(8, 10)) # tiny images: no binning
})

test_that("save_montage() writes a file of the exact size", {
  skip_if_not_installed("png")
  images <- local_montage_images()
  path <- withr::local_tempfile(fileext = ".png")
  m <- tidymontage(images) |>
    adjust_colors(C2 = "white") |> adjust_layout(x = condition, y = channel) |>
    adjust_size(width = 50.8 - strip_mm(7), height = NA)
  expect_message(save_montage(m, path, dpi = 100), "Saved")
  p <- png::readPNG(path)
  panel_w <- (50.8 - strip_mm(7) - 1) / 2
  height <- strip_mm(7) + 2 * panel_w * 0.8 + 1
  expect_equal(dim(p)[2], 200) # 2 inches at 100 dpi
  expect_lte(abs(dim(p)[1] - height / 25.4 * 100), 1)
})

test_that("montages render consistently", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  images <- local_montage_images()
  m <- tidymontage(images) |>
    adjust_exposure(min = 0, max = "p100") |> adjust_layout(x = condition, y = channel)
  vdiffr::expect_doppelganger("grid of two conditions", drawing(m))
  vdiffr::expect_doppelganger("row of channels", drawing(adjust_layout(m, x = channel, y = NULL, condition = "ko")))
})

test_that("save_montage() writes every supported format, and refuses others", {
  m <- tidymontage(local_montage_images(), x = condition, width = 30, height = NA)
  dir <- withr::local_tempdir()
  devices <- grDevices::dev.list()
  for (ext in c("png", "pdf", "svg", "tif", "jpg")) {
    path <- file.path(dir, paste0("montage.", ext))
    expect_message(save_montage(m, path, dpi = 72), "Saved")
    expect_gt(file.size(path), 0)
  }
  expect_error(save_montage(m, file.path(dir, "montage.bmp")), "Can't save")
  # no device is left open
  expect_identical(grDevices::dev.list(), devices)
})

test_that("save_montage() falls back when Cairo can't open a device", {
  skip_if_not_installed("svglite")
  m <- tidymontage(local_montage_images(), x = condition, width = 30, height = NA)
  dir <- withr::local_tempdir()
  devices <- grDevices::dev.list()
  # as on macOS without XQuartz: the Cairo devices warn and open nothing
  local_mocked_bindings(
    cairo_pdf_device = function(...) warning("unable to load cairo"),
    cairo_svg_device = function(...) warning("unable to load cairo")
  )
  for (ext in c("pdf", "svg")) {
    path <- file.path(dir, paste0("montage.", ext))
    expect_message(save_montage(m, path, dpi = 72), "Saved")
    expect_gt(file.size(path), 0)
  }
  expect_match(readLines(file.path(dir, "montage.pdf"), n = 1, warn = FALSE), "%PDF")
  expect_match(paste(readLines(file.path(dir, "montage.svg"), warn = FALSE), collapse = ""), "<svg")
  expect_identical(grDevices::dev.list(), devices)
})

test_that("print() draws at the physical size without errors", {
  m <- tidymontage(local_montage_images(), x = condition)
  path <- withr::local_tempfile(fileext = ".pdf")
  grDevices::pdf(path, width = 8, height = 8)
  on.exit(grDevices::dev.off())
  expect_invisible(print(m))
})
