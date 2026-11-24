# local_montage_images(): C1 = 0..79 (ctrl) and 100..179 (ko); C2 = 1000 + the same.

test_that("preview_exposure() shows a min x max grid of one image", {
  m <- tidymontage(local_montage_images(), x = condition)
  expect_message(p <- preview_exposure(m, "C1"), "the brightest of 2 images")
  panels <- montage_panels(p)
  expect_equal(nrow(panels), 25)
  expect_equal(max(panels$col), 5)
  expect_equal(max(panels$row), 5)
  # the brightest image (ko) is shown, all panels the same image
  expect_equal(unique(p$images$condition), "ko")
  # max on the columns, from dark to bright; min on the rows, background darker downwards
  expect_equal(levels(p$images$max_option), c("max p100", "max p99.99", "max p99.9", "max p99", "max p98"))
  expect_equal(levels(p$images$min_option), c("min p0", "min p0.1", "min p1", "min p5", "min p10"))
  expect_equal(montage_spec(p)$mapping$x, "max_option")
  expect_equal(montage_spec(p)$mapping$y, "min_option")
  first <- panels[panels$row == 1 & panels$col == 1, ]
  expect_equal(nrow(first), 1)
})

test_that("display ranges come from all images sharing the range", {
  m <- tidymontage(local_montage_images(), x = condition)
  p <- suppressMessages(preview_exposure(m, "C1"))
  pool <- c(0:79, 100:179)
  current <- p$images[p$images$.outline, ]
  expect_equal(nrow(current), 1)
  expect_equal(current$display_min, stats::quantile(pool, 0.001, names = FALSE))
  expect_equal(current$display_max, stats::quantile(pool, 0.999, names = FALSE))

  # unlinked on purpose: only the image's own pixels
  m2 <- adjust_exposure(m, .by = c(channel, condition))
  expect_message(p2 <- preview_exposure(m2, "C1", condition == "ctrl"), "from 1 image")
  current <- p2$images[p2$images$.outline, ]
  expect_equal(current$display_max, stats::quantile(0:79, 0.999, names = FALSE))
})

test_that("the grid centres on the current exposure", {
  m <- tidymontage(local_montage_images(), x = condition) |> adjust_exposure(min = "p5", max = "p99")
  p <- suppressMessages(preview_exposure(m, "C1"))
  expect_equal(levels(p$images$min_option), c("min p0.1", "min p1", "min p5", "min p10", "min p25"))
  expect_equal(levels(p$images$max_option), c("max p99.99", "max p99.9", "max p99", "max p98", "max p95"))
  current <- p$images[p$images$.outline, ]
  expect_equal(as.character(current$min_option), "min p5")

  # intensity values are placed at their percentile
  steps <- exposure_steps(list(type = "value", value = 50), exposure_ladder$max, 1:100)
  expect_equal(steps$steps[steps$current], 50)
})

test_that("preview_exposure() renders with the channel colour and outlines the current option", {
  m <- tidymontage(local_montage_images(), x = condition) |> adjust_colors(C1 = "black")
  p <- suppressMessages(preview_exposure(m, "C1", condition == "ctrl"))
  b <- montage_build(p, dpi = 72)
  expect_equal(unique(b$panels$.background), "white")
  expect_equal(sum(b$panels$.outline), 1)
  el <- montage_grob(b)$children
  outline <- Filter(function(g) g$name == "outline", el)[[1]]
  expect_equal(outline$gp$col, "#E69F00")
})

test_that("preview_exposure() explains what is wrong", {
  m <- tidymontage(local_montage_images(), x = condition)
  expect_error(preview_exposure(m), "Choose a")
  expect_error(preview_exposure(m, "C9"), "one channel of the montage")
  expect_error(preview_exposure(m, "C1", condition == "none"), "pick 0")
})

test_that("preview_positions() shows one image per block with relative axes", {
  m <- tidymontage(local_montage_images(), x = condition) |>
    add_merge(C1, C2) |>
    add_crop(width = 0.6, height = 0.48) |>
    add_zoom(width = 0.2, height = 0.16)
  p <- preview_positions(m)
  s <- montage_layout_space(p, call = NULL)
  expect_equal(s$panels$channel, c("merge", "merge"))
  expect_equal(s$panels$condition, c("ctrl", "ko"))
  # full images, not the crop
  expect_equal(unique(s$panels$.x1 - s$panels$.x0 + 1), 10)

  pv <- s$preview
  expect_equal(sum(pv$ticks$y > max(s$panels$ymax)), 2 * 6) # x labels below
  expect_equal(unique(pv$ticks$label), as.character(seq(0, 1, by = 0.2)))
  expect_equal(nrow(pv$lines), 2 * 18) # 9 + 9 grid lines per image
  expect_equal(pv$rects$label, rep(c("crop", "zoom"), 2))
  # the crop outline: 6 x 5 px around the image centre of a 10 x 8 px image
  first <- s$panels[1, ]
  crop <- pv$rects[1, ]
  expect_equal((crop$xmax - crop$xmin) / (first$xmax - first$xmin), 6 / 10)
})

test_that("preview_positions() picks images and falls back to files", {
  m <- tidymontage(local_montage_images(), x = condition)
  p <- preview_positions(m, condition == "ko")
  expect_equal(montage_panels(p)$condition, "ko")
  expect_equal(montage_panels(p)$channel, "C1")

  images <- local_montage_images()
  p <- preview_positions(tidymontage(images, channel = "C2"), condition == "ctrl")
  expect_equal(montage_panels(p)$file, "ctrl.tif")
  expect_error(preview_positions(m, condition == "none"), "no images")
})

test_that("previews render consistently", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  m <- tidymontage(local_montage_images(), x = condition) |>
    add_merge(C1, C2) |>
    add_crop(width = 0.6, height = 0.48)
  vdiffr::expect_doppelganger("preview exposure", drawing(suppressMessages(preview_exposure(m, "C1"))))
  vdiffr::expect_doppelganger("preview positions", drawing(preview_positions(m)))
})
