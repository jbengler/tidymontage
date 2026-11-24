# local_montage_images(): C1 = 0..79 (+100 for ko), C2 = 1000 + the same.
# Original colours: C1 magenta, C2 green.

test_that("lut() takes colormap names or colours, and validates", {
  expect_equal(format(lut("Magma")), "lut(\"magma\")")
  expect_equal(format(lut("viridis", reverse = TRUE)), "lut(\"viridis\", reverse = TRUE)")
  expect_equal(format(lut(c("black", "red"))), "lut(c(\"black\", \"red\"))")

  expect_error(lut("red"), "at least two colours")
  expect_error(lut("nope"), "Unknown colormap")
  expect_error(lut(c("red", "nope")), "invalid colour")
  expect_error(lut(1:3), "colormap name or a vector")
  expect_error(lut("magma", reverse = NA), "reverse")
})

test_that("LUT tables run from the first to the last colour", {
  t <- lut_table(lut("magma"))
  expect_length(t, 256)
  expect_equal(t[c(1, 256)], c("#000004", "#FCFDBF"))
  expect_equal(lut_table(lut("magma", reverse = TRUE)), rev(t))
  expect_equal(lut_table(lut(c("black", "white")))[c(1, 256)], c("#000000", "#FFFFFF"))
})

test_that("adjust_colors() takes LUTs, and hints at lut() for colormap names", {
  m <- tidymontage(example_images())
  expect_equal(
    format(adjust_colors(m, GFP = lut("magma"), DAPI = "blue")$steps[[1]]),
    "adjust_colors(GFP = lut(\"magma\"), DAPI = \"blue\")"
  )
  expect_error(adjust_colors(m, GFP = "magma"), "lut")
  expect_error(adjust_colors(m, GFP = 3), "single valid colour or a LUT")
})

test_that("a LUT channel is drawn through its map, on its first colour", {
  m <- tidymontage(local_montage_images(), x = condition, channel = "C1") |>
    adjust_colors(C1 = lut(c("blue", "red"))) |>
    adjust_exposure(min = 0, max = 179)
  p <- montage_panels(m)
  expect_equal(p$background, c("#0000FF", "#0000FF"))

  b <- montage_build(m, dpi = 72)
  ctrl <- unpack_rgb(b$rasters[[1]])
  values <- matrix(0:79, 8, 10, byrow = TRUE)
  table <- grDevices::col2rgb(lut_table(lut(c("blue", "red"))))
  idx <- round(values / 179 * 255) + 1
  expect_equal(ctrl$red, matrix(table[1, idx], 8, 10))
  expect_equal(ctrl$blue, matrix(table[3, idx], 8, 10))
  expect_equal(c(ctrl$red[1, 1], ctrl$blue[1, 1]), c(0, 255))
})

test_that("light LUT panels get dark zoom boxes and frames", {
  m <- tidymontage(local_montage_images(), x = condition, channel = "C1") |>
    adjust_colors(C1 = lut("magma", reverse = TRUE)) |>
    add_zoom(width = 5, height = 4, units = "px")
  s <- montage_layout_space(m, call = NULL)
  expect_true(all(s$boxes$color == "black"))
  expect_true("frames" %in% names(montage_elements(m)))
})

test_that("in merges, LUT channels use their original colour or the merge's", {
  m <- tidymontage(local_montage_images(), x = condition, channel = c("C1", "plain", "custom")) |>
    adjust_colors(C1 = lut("magma")) |>
    add_merge(C1, C2, name = "plain") |>
    add_merge(C1, C2, name = "custom", colors = c(C1 = "red"))
  s <- montage_layout_space(m, call = NULL)
  p <- s$panels
  expect_equal(p$.colors[p$channel == "plain"][[1]], c("#FF00FF", "#00FF00"))
  expect_equal(p$.colors[p$channel == "custom"][[1]], c("red", "#00FF00"))
  expect_null(p$.lut[p$channel == "plain"][[1]])
  expect_equal(unique(p$.background[p$channel != "C1"]), "black")

  expect_error(
    add_merge(m, C1, C2, name = "bad", colors = list(C1 = lut("magma"))),
    "single colour, not a LUT"
  )
})

test_that("overlays can be coloured with a LUT", {
  m <- tidymontage(local_montage_images(), x = condition, channel = "o") |>
    adjust_exposure(min = 0, max = 79) |>
    add_overlay(C1, C2, name = "o", color = lut(c("black", "white")))
  expect_equal(format(m$steps[[2]]), "add_overlay(C1, C2, name = \"o\", color = lut(c(\"black\", \"white\")))")
  b <- montage_build(m, dpi = 72)
  rgb <- unpack_rgb(b$rasters[[1]])
  expect_equal(rgb$red, rgb$green)
  expect_equal(rgb$red[1, 1], 0)
  expect_gt(rgb$red[8, 10], 200)
  expect_error(add_overlay(m, C1, C2, name = "o2", color = "magma"), "lut")
})

test_that("the legend shows LUT channels as labelled colour bars", {
  m <- tidymontage(local_montage_images(), x = condition) |>
    adjust_colors(C1 = lut("magma")) |>
    adjust_exposure(min = 0, max = 179) |>
    add_merge(C1, C2) |>
    add_color_legend()
  s <- montage_layout_space(m, call = NULL)
  lg <- s$legend
  expect_equal(lg$label, c("C1", "C2", "merge: C1"))
  # bars are wider than swatches
  w <- lg$xmax - lg$xmin
  expect_gt(w[1], 3 * w[2])
  expect_true(is_lut(lg$lut[[1]]))
  expect_null(lg$lut[[2]])

  b <- montage_build(m, dpi = 72)
  expect_equal(b$legend$range_lo, c("0", NA, NA))
  expect_equal(b$legend$range_hi, c("179", NA, NA))
  el <- montage_elements(m)
  expect_true(all(c("legend-bar-1", "legend-range-lo-1", "legend-range-hi-1") %in% names(el)))

  # range labels need room: a legend with bars and ranges is taller
  plain <- tidymontage(local_montage_images(), x = condition) |> add_color_legend()
  expect_gt(s$height, montage_layout_space(plain, call = NULL)$height)
  no_ranges <- montage_layout_space(add_color_legend(m, ranges = FALSE), call = NULL)
  expect_lt(no_ranges$height, s$height)
  expect_equal(format(add_color_legend(m, ranges = FALSE)$steps[[5]]), "add_color_legend(ranges = FALSE)")
})

test_that("colour bars of unlinked channels stay unlabelled, with a message", {
  m <- tidymontage(local_montage_images(), x = condition) |>
    adjust_colors(C1 = lut("magma")) |>
    adjust_exposure(.by = c(channel, condition)) |>
    add_color_legend()
  expect_message(b <- montage_build(m, dpi = 72), "not labelled")
  expect_true(all(is.na(b$legend$range_lo)))
})

test_that("a LUT channel shown only in merges gets no colour bar", {
  m <- tidymontage(local_montage_images(), x = condition, channel = "merge") |>
    adjust_colors(C1 = lut("magma")) |>
    add_merge(C1, C2) |>
    add_color_legend()
  lg <- montage_layout_space(m, call = NULL)$legend
  expect_equal(lg$label, c("C2", "C1"))
  expect_equal(lg$color, c("#00FF00", "#FF00FF"))
})
