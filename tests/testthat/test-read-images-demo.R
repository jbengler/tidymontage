# Tests on real microscope exports. The demo images are not part of the
# package (too large), so these tests only run in a local checkout.

demo_dir <- function() {
  dir <- test_path("../../demo_images")
  skip_if_not(dir.exists(dir), "demo images not available")
  dir
}

test_that("the three TIFF exports of one cell agree", {
  dir <- demo_dir()
  files <- list.files(dir, "12_23_13.*\\.tif$", full.names = TRUE)
  skip_if_not(length(files) == 3)
  x <- read_images(files)

  expect_equal(nrow(x), 9)
  expect_equal(sort(unique(x$meta_source)), c("imagej", "ome-xml"))
  expect_equal(unique(x$color), c("#FF00FF", "#00FF00", "#FFFFFF"))
  expect_equal(unique(round(x$pixel_size, 5)), 0.07072)
  for (ch in 1:3) {
    rows <- x[x$channel_index == ch, ]
    p <- img_pixels(rows$img)
    expect_identical(p[[2]], p[[1]])
    expect_identical(p[[3]], p[[1]])
  }
})

test_that("ImageJ z-stack: planes follow the slice labels", {
  dir <- demo_dir()
  path <- file.path(dir, "DIV14Actin-01-Airyscan Processing-02.tif")
  skip_if_not(file.exists(path))
  x <- read_images(path)

  expect_equal(nrow(x), 28)
  expect_equal(unique(x$channel), c("Alexa Fluor 647", "Alexa Fluor 555", "Alexa Fluor 488", "Hoechst 33258"))
  expect_equal(unique(x$size_z), 7L)
  expect_equal(unique(x$z_step), 1.8, tolerance = 1e-6)

  labels <- ij_private(tiff_open(path))$labels
  for (c in 1:4) {
    pages <- vapply(vctrs::vec_data(x$img[x$channel_index == c]), function(r) r$node$page, integer(1))
    expect_true(all(startsWith(labels[pages], sprintf("c:%d/4 z:%d/7", c, 1:7))))
  }
})
