# Fake images: no files behind them, enough for layouts and formatting.
example_images <- function() {
  tibble::tibble(
    filepath = rep(c("ctrl.tif", "ko.tif"), each = 2),
    channel = rep(c("DAPI", "GFP"), times = 2),
    condition = rep(c("ctrl", "ko"), each = 2),
    img = new_img(lapply(1:4, function(i) img_source("fake.tif", page = i, size_x = 5L, size_y = 4L)))
  )
}

# Real images on disk: two conditions x two channels, 8 x 10 pixels.
# Pixel values: channel 1 = 0..79 (ctrl) or 100..179 (ko); channel 2 = 1000 + same.
local_montage_images <- function(env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  for (cond in c("ctrl", "ko")) {
    offset <- if (cond == "ctrl") 0L else 100L
    planes <- lapply(c(0L, 1000L), function(base) {
      matrix(base + offset + 0:79, 8, 10, byrow = TRUE)
    })
    desc <- "ImageJ=1.54p\nimages=2\nchannels=2\nhyperstack=true\nunit=micron\n"
    write_test_tiff(
      file.path(dir, paste0(cond, ".tif")), planes,
      tags = c(
        list(list(270, 2, desc), list(282, 5, 10), list(283, 5, 10)),
        ij_private_tags(luts = list(test_lut(c(255, 0, 255)), test_lut(c(0, 255, 0))), endian = "little")
      )
    )
  }
  images <- read_images(dir)
  images$condition <- sub("\\.tif$", "", basename(images$filepath))
  images
}

# Red, green and blue matrices of a nativeRaster.
unpack_rgb <- function(r) {
  v <- as.numeric(unclass(r)) + 2^32 * (unclass(r) < 0)
  list(
    red = matrix(v %% 256, nrow(r), byrow = TRUE),
    green = matrix((v %/% 256) %% 256, nrow(r), byrow = TRUE),
    blue = matrix((v %/% 65536) %% 256, nrow(r), byrow = TRUE)
  )
}

