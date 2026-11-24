hero_montage <- function(images, ...) {
  tidymontage(images, x = condition, layout = layout_hero(...)) |>
    add_merge(C1, C2) |>
    add_crop(width = 0.6) |>
    add_zoom(width = 0.3)
}

test_that("the hero shows the merge with the zoomed channels beside it", {
  # without side labels, the panels and gaps fill the 90 mm box exactly
  p <- montage_panels(hero_montage(local_montage_images(), labels = FALSE))
  expect_equal(p$role, rep(c("hero", "side", "side"), 2))
  expect_equal(p$channel, rep(c("merge", "C1", "C2"), 2))
  expect_equal(p$view, rep(c("crop", "zoom", "zoom"), 2))
  expect_equal(p$condition, rep(c("ctrl", "ko"), each = 3))
  expect_equal(p$col, rep(1:2, each = 3))

  hero <- p[p$condition == "ctrl" & p$role == "hero", ]
  side <- p[p$condition == "ctrl" & p$role == "side", ]
  # side panels stack to the hero's height, with a 1 mm gap
  expect_equal(max(side$ymax) - min(side$ymin), hero$ymax - hero$ymin)
  expect_equal(side$ymin[2] - side$ymax[1], 1)
  expect_equal(side$xmin[1] - hero$xmax, 1)
  # blocks are 3 mm apart and the panels fit 90 mm
  expect_equal(p$xmin[4] - max(p$xmax[1:3]), 3)
  expect_equal(max(p$xmax) - min(p$xmin), 90)
})

test_that("side panels can go below or left of the hero", {
  p <- montage_panels(hero_montage(local_montage_images(), position = "bottom", labels = FALSE))
  hero <- p[p$condition == "ctrl" & p$role == "hero", ]
  side <- p[p$condition == "ctrl" & p$role == "side", ]
  expect_equal(unique(side$ymin), hero$ymax + 1)
  expect_equal(max(side$xmax) - min(side$xmin), hero$xmax - hero$xmin)

  p <- montage_panels(hero_montage(local_montage_images(), position = "left", labels = FALSE))
  hero <- p[p$condition == "ctrl" & p$role == "hero", ]
  side <- p[p$condition == "ctrl" & p$role == "side", ]
  expect_equal(hero$xmin, side$xmax[1] + 1)
})

test_that("hero and side panels can be chosen with panel()", {
  p <- montage_panels(hero_montage(local_montage_images(), hero = panel(channel = "C1", view = "crop"), side = panel(channel = c("C2", "merge"), view = "zoom")))
  expect_equal(p$channel[p$condition == "ctrl"], c("C1", "C2", "merge"))
})

test_that("without merge or zoom, the hero uses the first channel and the main view", {
  m <- tidymontage(local_montage_images(), x = condition, layout = "hero")
  p <- montage_panels(m)
  expect_equal(p$channel[p$role == "hero"], c("C1", "C1"))
  expect_equal(unique(p$view), "full")
  expect_equal(p$channel[p$role == "side" & p$condition == "ctrl"], c("C1", "C2"))
})

test_that("switching layouts keeps the mapping, channel and view in x/y are ignored", {
  m <- tidymontage(local_montage_images(), x = c(condition, channel)) |> add_merge(C1, C2)
  expect_message(p <- montage_panels(adjust_layout(m, layout = "hero")), "arranges .*channel")
  expect_equal(max(p$col), 2)
})

test_that("the hero layout explains what is wrong", {
  m <- tidymontage(local_montage_images(), layout = "hero")
  expect_error(montage_panels(m), "exactly one hero panel")
  expect_error(
    montage_panels(add_merge(add_merge(tidymontage(local_montage_images(), x = condition, layout = "hero"), C1, C2), C1, C2, name = "m2")),
    "can't choose between the merges"
  )
  expect_error(
    montage_panels(hero_montage(local_montage_images(), side = panel(channel = "C9"))),
    "no side panels"
  )
})

hero_space <- function(m) montage_layout_space(m, call = NULL)

test_that("side panels are labelled with their channel, outside the images", {
  images <- local_montage_images()
  for (pos in c("bottom", "right", "left")) {
    with <- hero_space(hero_montage(images, position = pos))
    without <- hero_space(hero_montage(images, position = pos, labels = FALSE))
    # labels never change the panel sizes
    expect_equal(with$panels$xmax - with$panels$xmin, without$panels$xmax - without$panels$xmin)
    expect_equal(with$panels$ymax - with$panels$ymin, without$panels$ymax - without$panels$ymin)
    expect_null(without$side_labels)

    sl <- with$side_labels
    side <- with$panels[with$panels$.role == "side", ]
    expect_equal(sl$label, side$.label)
    expect_equal(sl$label, rep(c("C1", "C2"), 2))
    line_h <- 7 * 0.3528 * 1.25
    if (pos == "bottom") {
      expect_equal(sl$x, (side$xmin + side$xmax) / 2)
      expect_equal(sl$y, side$ymax + 0.8)
      expect_equal(unique(sl$angle), 0)
      expect_equal(with$height, without$height + 0.8 + line_h)
      expect_equal(with$width, without$width)
    } else {
      # rotated like ggplot2 facet strips, in a strip one text line wide
      expect_equal(sl$y, (side$ymin + side$ymax) / 2)
      expect_equal(unique(sl$angle), if (pos == "right") -90 else 90)
      # all labels start at the same distance from their panel
      expect_equal(sl$x, if (pos == "right") side$xmax + 0.8 else side$xmin - 0.8)
      expect_equal(unique(sl$vjust), 0)
      expect_equal(with$width, without$width + 2 * (0.8 + line_h))
      expect_equal(with$height, without$height)
      expect_true(all(sl$x >= 0))
    }
  }
})

test_that("side panels that differ by view are labelled with the view", {
  m <- tidymontage(local_montage_images(), x = condition, layout = layout_hero(
    hero = panel(channel = "merge", view = "crop"),
    side = panel(channel = "merge", view = c("crop", "zoom"))
  )) |>
    add_merge(C1, C2) |>
    add_crop(width = 0.6) |>
    add_zoom(width = 0.3)
  expect_equal(hero_space(m)$side_labels$label, rep(c("crop", "zoom"), 2))
})

test_that("long labels below side panels wrap, or warn if they still don't fit", {
  expect_equal(wrap_labels("Alexa Fluor 488", 100, 7), "Alexa Fluor 488")
  expect_equal(wrap_labels("Alexa Fluor 488", 12, 7), "Alexa\nFluor 488")
  expect_warning(out <- wrap_labels("Supercalifragilistic", 5, 7), "longer than the side panels")
  expect_equal(out, "Supercalifragilistic")

  images <- local_montage_images()
  images$channel[images$channel == "C1"] <- "first channel"
  s <- hero_space(
    tidymontage(images, x = condition, layout = layout_hero(position = "bottom"), width = 40, height = NA) |>
      add_merge(`first channel`, C2)
  )
  expect_match(s$side_labels$label[1], "\n")
})

test_that("rotated side labels wrap to the panel height", {
  images <- local_montage_images()
  images$channel[images$channel == "C1"] <- "first channel"
  s <- hero_space(
    tidymontage(images, x = condition, layout = "hero") |>
      add_merge(`first channel`, C2)
  )
  expect_match(s$side_labels$label[1], "\\n")
  # two lines of text: the strip is wider, the labels still start at the panel
  side <- s$panels[s$panels$.role == "side", ]
  expect_equal(s$side_labels$x, side$xmax + 0.8)
  wide <- s$width
  s1 <- hero_space(tidymontage(local_montage_images(), x = condition, layout = "hero") |> add_merge(C1, C2))
  expect_equal(wide - s1$width, 2 * 7 * 0.3528 * 1.25)
})

test_that("side labels can be switched off and print", {
  expect_equal(format(layout_hero(labels = FALSE)), "layout_hero(labels = FALSE)")
  expect_equal(format(layout_hero(labels = TRUE)), "\"hero\"")
})

test_that("hero montages render consistently", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  m <- hero_montage(local_montage_images()) |> adjust_exposure(min = 0, max = "p100") |> add_scale_bar()
  vdiffr::expect_doppelganger("hero layout", autoplot(m, dpi = 72))
})
