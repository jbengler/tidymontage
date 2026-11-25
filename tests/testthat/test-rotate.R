# local_montage_images(): 10 x 8 pixels, value = 10 * y + x (0-based pixels),
# a linear ramp, so bilinear interpolation gives exact values.

rot_space <- function(m) montage_layout_space(m, call = NULL)
ramp <- matrix(0:79, 8, 10, byrow = TRUE)

test_that("rotated regions sample the image along the rotated grid", {
  m <- tidymontage(local_montage_images(), x = condition, channel = "C1") |>
    add_crop(width = 4, center = c(5, 4), units = "px", center_units = "px", angle = 30)
  p <- rot_space(m)$panels
  expect_equal(p$.angle, c(30, 30))
  out <- panel_pixels(ramp, p, 1)
  expect_equal(dim(out), c(4, 4))
  # output pixel (row j, column i) comes from c + u * e1 + v * e2
  a <- 30 * pi / 180
  u <- (1:4 - 0.5) - 2
  v <- (1:4 - 0.5) - 2
  expected <- outer(v, u, function(v, u) {
    x <- 5 + u * cos(a) + v * sin(a)
    y <- 4 - u * sin(a) + v * cos(a)
    10 * (y - 0.5) + (x - 0.5)
  })
  expect_equal(out, expected)
  # along the panel's x axis, the image is followed 30 degrees counterclockwise:
  # x increases by cos(a), y decreases by sin(a) per pixel
  expect_equal(out[1, 2] - out[1, 1], cos(a) - 10 * sin(a))
})

test_that("a quarter turn rotates the pixels exactly", {
  m <- tidymontage(local_montage_images(), x = condition, channel = "C1") |>
    add_crop(width = 4, center = c(5, 4), units = "px", center_units = "px", angle = 90)
  p <- rot_space(m)$panels
  block <- ramp[3:6, 4:7]
  # the panel's x axis points up the image, its y axis to the right
  expect_equal(panel_pixels(ramp, p, 1), t(block)[, 4:1])
})

test_that("upright regions are unchanged", {
  m <- tidymontage(local_montage_images(), x = condition, channel = "C1") |>
    add_crop(width = 4, center = c(5, 4), units = "px", center_units = "px")
  p <- rot_space(m)$panels
  expect_equal(p$.angle, c(0, 0))
  expect_equal(panel_pixels(ramp, p, 1), ramp[3:6, 4:7])
  expect_equal(get_panels(m)$angle, c(0, 0))
})

test_that("angles can differ per image and must keep the region inside", {
  centers <- data.frame(condition = c("ctrl", "ko"), x = 0.5, y = 0.5, angle = c(20, -45))
  m <- tidymontage(local_montage_images(), x = condition, channel = "C1") |>
    add_crop(width = 4, center = centers, units = "px")
  expect_equal(get_panels(m)$angle, c(20, 315))
  expect_equal(format(m$steps[[1]]), 'add_crop(width = 4, center = <2 centers and angles by condition>, units = "px", name = "crop")')

  # corners of a 8 x 8 region at 45 degrees reach beyond the 10 x 8 image
  far <- tidymontage(local_montage_images(), x = condition, channel = "C1") |>
    add_crop(width = 6, units = "px", angle = 45)
  expect_error(rot_space(far), "reaches beyond the image")
})

test_that("zooms inherit the crop's angle unless given one", {
  base <- tidymontage(local_montage_images(), x = c(condition, view), channel = "C1") |>
    add_crop(width = 6, height = 4, units = "px", angle = 10)
  m <- base |> add_zoom(width = 3, height = 2, units = "px")
  s <- rot_space(m)
  expect_equal(unique(s$panels$.angle), 10)
  # the box sits square in the crop panel
  b <- s$boxes[1, ]
  expect_equal(c(b$y1, b$x2, b$y3, b$x4), c(b$y2, b$x3, b$y4, b$x1))

  m <- base |> add_zoom(width = 3, height = 2, units = "px", angle = 0)
  s <- rot_space(m)
  expect_equal(s$panels$.angle[s$panels$view == "zoom"], c(0, 0))
  # tilted by -10 degrees relative to the crop: the top edge falls to the right
  b <- s$boxes[1, ]
  expect_gt(b$y2, b$y1)
  expect_equal(atan2(b$y2 - b$y1, b$x2 - b$x1) * 180 / pi, 10)
  expect_equal(format(m$steps[[2]]), 'add_zoom(width = 3, height = 2, center = c(0.5, 0.5), units = "px", angle = 0)')
})

test_that("arrowheads and previews follow rotated regions", {
  m <- tidymontage(local_montage_images(), x = condition, channel = "C1") |>
    add_crop(width = 4, center = c(5, 4), units = "px", center_units = "px", angle = 30) |>
    add_arrows(c(5, 4), units = "px")
  s <- rot_space(m)
  p <- s$panels
  # the crop's center is the panel's center
  expect_equal(s$arrows$x, (p$xmin + p$xmax) / 2)
  expect_equal(s$arrows$y, (p$ymin + p$ymax) / 2)

  pv <- rot_space(preview_positions(m))$preview$rects
  expect_equal(pv$label, c("crop", "crop"))
  # outlined as a rotated square
  expect_false(isTRUE(all.equal(pv$y1, pv$y2)))
})

test_that("angle is validated", {
  m <- tidymontage(example_images())
  expect_error(add_crop(m, width = 1, angle = "a"), "single number")
  expect_error(add_zoom(m, width = 1, angle = c(1, 2)), "single number")
  centers <- data.frame(condition = c("ctrl", "ko"), x = 0.5, y = 0.5, angle = 10)
  expect_error(add_crop(m, width = 1, center = centers, angle = 5), "not both")
  centers$angle <- "a"
  expect_error(add_crop(m, width = 1, center = centers), "must be numeric")
  # arrows have no angle
  expect_error(add_arrows(m, data.frame(x = 0.5, y = 0.5, angle = 1)), "not in the images tibble")
})
