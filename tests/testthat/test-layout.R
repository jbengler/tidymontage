test_that("x and y in tidymontage() place panels in rows and columns", {
  p <- tidymontage(example_images(), x = condition, y = channel, gap = 2, width = 100, height = NA) |>
    get_panels()

  expect_equal(nrow(p), 4)
  expect_equal(p$col, c(1, 2, 1, 2))
  expect_equal(p$row, c(1, 1, 2, 2))
  expect_equal(p$channel, c("DAPI", "DAPI", "GFP", "GFP"))
  # the 100 mm hold panels and gaps; header strips are added outside
  strip <- strip_mm(7)
  panel_w <- (100 - 2) / 2
  expect_equal(p$xmin, c(strip, strip + panel_w + 2, strip, strip + panel_w + 2))
  expect_equal(p$xmax - p$xmin, rep(panel_w, 4))
  expect_equal(p$ymax - p$ymin, rep(panel_w * 4 / 5, 4))
  expect_equal(p$ymin[3], strip + panel_w * 4 / 5 + 2)
})

test_that("the grid places channel and view on a free axis", {
  # nothing mapped: a row of channels
  p <- get_panels(tidymontage(example_images()[1:2, ]))
  expect_equal(p$channel, c("DAPI", "GFP"))
  expect_equal(p$col, 1:2)

  # conditions on x: channels go to the rows
  p <- get_panels(tidymontage(example_images(), x = condition))
  expect_equal(p$row, c(1, 1, 2, 2))
  expect_equal(p$channel, c("DAPI", "DAPI", "GFP", "GFP"))

  # conditions on y: channels go to the columns
  p <- get_panels(tidymontage(example_images(), y = condition))
  expect_equal(p$col, c(1, 2, 1, 2))

  # layout_grid() sets the axis explicitly
  p <- get_panels(tidymontage(example_images(), x = condition, layout = layout_grid(channel = "x")))
  expect_equal(p$col, 1:4)
  expect_equal(paste(p$condition, p$channel), c("ctrl DAPI", "ctrl GFP", "ko DAPI", "ko GFP"))
})

test_that("views go to the other axis, nested inside the mapped columns", {
  m <- tidymontage(local_montage_images(), x = condition) |>
    add_crop(width = 0.6) |>
    add_zoom(width = 0.3)
  p <- get_panels(m)
  # channels on rows, views inside conditions on columns
  expect_equal(p$view[p$row == 1], c("crop", "zoom", "crop", "zoom"))
  expect_equal(p$condition[p$row == 1], c("ctrl", "ctrl", "ko", "ko"))
  expect_equal(max(p$row), 2)
})

test_that("mapping channel or view yourself overrides the layout", {
  p <- get_panels(tidymontage(example_images(), x = channel, y = condition))
  expect_equal(p$channel, c("DAPI", "GFP", "DAPI", "GFP"))
  expect_equal(p$col, c(1, 2, 1, 2))

  m <- tidymontage(local_montage_images(), x = c(view, condition), y = channel) |>
    add_crop(width = 0.6) |>
    add_zoom(width = 0.3)
  p <- get_panels(m)
  expect_equal(p$view[p$row == 1], c("crop", "crop", "zoom", "zoom"))
})

test_that("channel needn't be placed if mapped columns determine it", {
  images <- example_images()
  images$target <- ifelse(images$channel == "DAPI", "nuclei", "protein")
  p <- get_panels(tidymontage(images, x = condition, y = target))
  expect_equal(p$channel, c("DAPI", "DAPI", "GFP", "GFP"))
  expect_equal(p$target, c("nuclei", "nuclei", "protein", "protein"))
  expect_equal(max(p$col), 2)
})

test_that("levels can be chosen and ordered", {
  p <- tidymontage(example_images(), x = channel, y = condition, channel = c("GFP", "DAPI"), condition = "ko") |>
    get_panels()
  expect_equal(p$channel, c("GFP", "DAPI"))
  expect_equal(p$condition, c("ko", "ko"))
})

test_that("factor levels set the order", {
  images <- example_images()
  images$condition <- factor(images$condition, levels = c("ko", "ctrl"))
  p <- get_panels(tidymontage(images, x = condition, y = channel))
  expect_equal(as.character(p$condition[p$row == 1]), c("ko", "ctrl"))
})

test_that("several dimensions can share an axis", {
  p <- get_panels(tidymontage(example_images(), x = c(condition, channel)))
  expect_equal(p$col, 1:4)
  expect_equal(paste(p$condition, p$channel), c("ctrl DAPI", "ctrl GFP", "ko DAPI", "ko GFP"))
})

test_that("adjust_layout() changes only what it is given", {
  m <- tidymontage(example_images(), x = condition, gap = 3, condition = "ctrl")
  p <- get_panels(adjust_layout(m, layout = layout_grid(channel = "x")))
  expect_equal(p$col, 1:2)
  expect_equal(unique(p$condition), "ctrl")
  expect_equal(p$xmin[2] - p$xmax[1], 3)

  p <- get_panels(adjust_layout(m, x = channel, y = condition, condition = c("ko", "ctrl"), gap = 0))
  expect_equal(p$condition, c("ko", "ko", "ctrl", "ctrl"))
  expect_equal(p$xmin[2], p$xmax[1])
})

test_that("layouts explain what is wrong", {
  m <- tidymontage(example_images())
  expect_snapshot(error = TRUE, {
    get_panels(adjust_layout(m, x = channel))
    adjust_layout(m, x = channel, y = channel)
    tidymontage(example_images(), x = genotype)
    tidymontage(example_images(), x = channel + 1)
    tidymontage(example_images(), colour = "red")
    tidymontage(example_images(), layout = "mosaic")
    tidymontage(example_images(), gap = -1)
    get_panels(tidymontage(example_images(), x = channel, channel = "RFP"))
    layout_hero(hero = list(channel = "merge"))
    panel("merge")
  })
})

test_that("panels must share one aspect ratio", {
  images <- example_images()
  images$img[2] <- new_img(list(img_source("fake.tif", page = 9, size_x = 5L, size_y = 5L)))
  expect_error(
    get_panels(tidymontage(images, x = condition, y = channel)),
    "same aspect ratio"
  )
})

test_that("layouts and panels print as calls", {
  expect_equal(format(layout_grid()), "\"grid\"")
  expect_equal(format(layout_grid(channel = "x")), 'layout_grid(channel = "x")')
  expect_equal(format(layout_hero()), "\"hero\"")
  expect_equal(
    format(layout_hero(hero = panel(channel = "merge"), position = "bottom")),
    'layout_hero(hero = panel(channel = "merge"), position = "bottom")'
  )
  m <- tidymontage(example_images(), x = condition, layout = "hero", width = 180, height = NA, condition = "ko")
  expect_equal(
    format(m)[2],
    'tidymontage(images, x = condition, condition = "ko", layout = "hero", width = 180, height = NA)'
  )
  expect_equal(format(adjust_layout(m, gap = 2)$steps[[1]]), "adjust_layout(gap = 2)")
})
