unpack_rgb <- function(r) {
  v <- as.numeric(unclass(r)) + 2^32 * (unclass(r) < 0)
  list(
    red = matrix(v %% 256, nrow(r), byrow = TRUE),
    green = matrix((v %/% 256) %% 256, nrow(r), byrow = TRUE),
    blue = matrix((v %/% 65536) %% 256, nrow(r), byrow = TRUE)
  )
}

test_that("light adds colours, black channels invert on white", {
  v <- list(matrix(c(0, 0.5, 1), 1), matrix(c(1, 1, 0), 1))
  light <- compose_panel(v, c("#FF0000", "#00FF00"), "black")
  expect_equal(light[[1]], matrix(c(0, 127.5, 255), 1))
  expect_equal(light[[2]], matrix(c(255, 255, 0), 1))

  # one black channel: inverted greyscale
  ink <- compose_panel(v[1], "#000000", "white")
  expect_equal(ink[[1]], matrix(c(255, 127.5, 0), 1))
  expect_equal(ink[[2]], ink[[1]])

  # black and red inks: red where only red, dark where black
  ink2 <- compose_panel(list(matrix(c(0, 1), 1), matrix(c(1, 0), 1)), c("#000000", "#FF0000"), "white")
  expect_equal(c(ink2[[1]][1], ink2[[2]][1], ink2[[3]][1]), c(255, 0, 0))
  expect_equal(c(ink2[[1]][2], ink2[[2]][2], ink2[[3]][2]), c(0, 0, 0))
})

test_that("black channels are drawn inverted on white, others on black", {
  m <- tidymontage(local_montage_images(), x = condition) |>
    adjust_colors(C1 = "black") |>
    adjust_exposure(min = 0, max = "p100")
  p <- montage_panels(m)
  expect_equal(p$background[p$channel == "C1"], c("white", "white"))
  expect_equal(p$background[p$channel == "C2"], c("black", "black"))

  b <- montage_build(m, dpi = 72)
  ctrl_c1 <- unpack_rgb(b$rasters[[which(b$panels$channel == "C1")[1]]])
  # pixel (1, 1) has the lowest value: white; brighter pixels are darker
  expect_equal(ctrl_c1$red[1, 1], 255)
  expect_lt(ctrl_c1$red[8, 10], ctrl_c1$red[1, 1])
  expect_equal(ctrl_c1$red, ctrl_c1$green)
})

test_that("merges are always on black; black members use their original colour", {
  images <- local_montage_images() # original colours: C1 magenta, C2 green
  m <- tidymontage(images, x = condition, channel = c("C1", "plain", "custom")) |>
    adjust_colors(C1 = "black", C2 = "black") |>
    add_merge(C1, C2, name = "plain") |>
    add_merge(C1, C2, name = "custom", colors = c(C2 = "red"))
  s <- montage_layout_space(m, call = NULL)
  p <- s$panels[s$panels$condition == "ctrl", ]
  expect_equal(p$.background, c("white", "black", "black"))
  expect_equal(p$.colors[[2]], c("#FF00FF", "#00FF00"))
  expect_equal(p$.colors[[3]], c("#FF00FF", "red"))
})

test_that("a member that stays black in a merge gives a warning", {
  images <- local_montage_images()
  images$color[images$channel == "C1"] <- "#000000"
  m <- tidymontage(images, x = condition) |> add_merge(C1, C2)
  expect_warning(montage_layout_space(m, call = NULL), "invisible on the black background")
  expect_silent(montage_layout_space(add_merge(tidymontage(images, x = condition), C1, C2, colors = c(C1 = "blue")), call = NULL))
})

test_that("zoom boxes and frames contrast with white panels", {
  m <- tidymontage(local_montage_images(), x = c(condition, view)) |>
    adjust_colors(C1 = "black") |>
    add_zoom(width = 0.5, height = 0.4)
  s <- montage_layout_space(m, call = NULL)
  expect_equal(sort(unique(s$boxes$color)), c("black", "white"))

  p <- autoplot(m, dpi = 72)
  frame_colours <- unlist(lapply(p$layers, function(l) if (inherits(l$geom, "GeomRect")) l$aes_params$colour))
  expect_true("black" %in% frame_colours)
})

test_that("the legend leaves out black channels and lists their merge colours", {
  images <- local_montage_images()
  base <- tidymontage(images, x = condition) |> adjust_colors(C1 = "black", C2 = "black")

  # one merge: plain channel names with the merge colours
  lg <- montage_layout_space(add_color_legend(add_merge(base, C1, C2, colors = c(C2 = "red"))), call = NULL)$legend
  expect_equal(lg$label, c("C1", "C2"))
  expect_equal(lg$color, c("#FF00FF", "#FF0000"))

  # two merges colouring C2 differently: prefixed, C1 agrees: plain
  m <- base |>
    add_merge(C1, C2, name = "a", colors = c(C2 = "red")) |>
    add_merge(C1, C2, name = "b", colors = c(C1 = "magenta", C2 = "green")) |>
    add_color_legend()
  lg <- montage_layout_space(m, call = NULL)$legend
  expect_equal(lg$label, c("C1", "a: C2", "b: C2"))

  # a merge colour that only differs from a visible channel colour keeps the prefix
  m <- tidymontage(images, x = condition) |> add_merge(C1, C2, colors = c(C2 = "red")) |> add_color_legend()
  expect_equal(montage_layout_space(m, call = NULL)$legend$label, c("C1", "C2", "merge: C2"))
})

test_that("a legend with only black channels is left out, without space", {
  m <- add_color_legend(tidymontage(local_montage_images(), x = condition) |> adjust_colors(C1 = "black", C2 = "black"))
  s <- montage_layout_space(m, call = NULL)
  expect_null(s$legend)
  s0 <- montage_layout_space(tidymontage(local_montage_images(), x = condition) |> adjust_colors(C1 = "black", C2 = "black"), call = NULL)
  expect_equal(s$height, s0$height)
})

test_that("wide legends wrap into rows", {
  images <- local_montage_images()
  images$channel[images$channel == "C1"] <- "a very long first channel name"
  images$channel[images$channel == "C2"] <- "an even longer second channel name"
  m <- tidymontage(images, x = condition, width = 40, height = NA) |> add_color_legend("bottom")
  lg <- montage_layout_space(m, call = NULL)$legend
  expect_equal(length(unique(lg$text_y)), 2)
})

test_that("add_merge() validates merge colours", {
  m <- tidymontage(local_montage_images())
  expect_snapshot(error = TRUE, {
    add_merge(m, C1, C2, colors = "red")
    add_merge(m, C1, C2, colors = c(C3 = "red"))
    add_merge(m, C1, C2, colors = c(C2 = "notacolour"))
  })
  expect_equal(
    format(add_merge(m, C1, C2, colors = c(C2 = "red"))$steps[[1]]),
    'add_merge(C1, C2, name = "merge", colors = c(C2 = "red"))'
  )
})

test_that("ink montages render consistently", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  m <- tidymontage(local_montage_images(), x = condition) |>
    adjust_exposure(min = 0, max = "p100") |>
    adjust_colors(C1 = "black", C2 = "black") |>
    add_merge(C1, C2, colors = c(C2 = "red")) |>
    add_color_legend()
  vdiffr::expect_doppelganger("ink montage", autoplot(m, dpi = 72))
})
