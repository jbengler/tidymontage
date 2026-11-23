test_that("plain 8-bit TIFF: one channel, no metadata", {
  m <- matrix(0:19, 4, 5, byrow = TRUE)
  path <- local_tiff(list(m), bits = 8)
  x <- read_images(path)

  expect_s3_class(x, "tbl_df")
  expect_equal(nrow(x), 1)
  expect_equal(x$channel, "C1")
  expect_equal(x$color, NA_character_)
  expect_equal(c(x$size_x, x$size_y, x$size_z, x$size_t), c(5L, 4L, 1L, 1L))
  expect_equal(x$bit_depth, 8L)
  expect_equal(x$meta_source, "tiff")
  expect_true(is.na(x$pixel_size))
  expect_true(is_img(x$img))
  expect_identical(pixels(x), m)
})

test_that("plain multi-page TIFF: pages become z-slices", {
  planes <- lapply(1:3, function(z) test_plane(z = z))
  for (bigtiff in c(FALSE, TRUE)) {
    x <- read_images(local_tiff(planes, bigtiff = bigtiff))
    expect_equal(x$z, 1:3)
    expect_equal(x$size_z, rep(3L, 3))
    expect_identical(pixels(x, z = 2), planes[[2]])
  }
})

test_that("TIFF resolution tags give a pixel size only in centimetres", {
  cm <- read_images(local_tiff(list(test_plane()), tags = list(list(282, 5, 141396.6), list(296, 3, 3))))
  expect_equal(cm$pixel_size, 1e4 / 141396.6, tolerance = 1e-6)
  expect_equal(cm$pixel_unit, "\u00b5m")
  expect_equal(cm$pixel_size_source, "tiff")

  inch <- read_images(local_tiff(list(test_plane()), tags = list(list(282, 5, 72), list(296, 3, 2))))
  expect_true(is.na(inch$pixel_size))
  expect_true(is.na(inch$pixel_size_source))
})

test_that("ImageJ hyperstack: CZT order, names, colours, calibration", {
  C <- 2
  Z <- 3
  T <- 2
  planes <- list()
  for (t in 1:T) for (z in 1:Z) for (c in 1:C) planes[[length(planes) + 1]] <- test_plane(c, z, t)
  desc <- paste0(
    "ImageJ=1.54p\nimages=12\nchannels=2\nslices=3\nframes=2\nhyperstack=true\n",
    "mode=composite\nunit=\\u00B5m\nspacing=0.5\nloop=false\n"
  )
  info <- paste(
    "Information|Image|Channel|Fluor #1 = Alexa Fluor 488",
    "Information|Image|Channel|Fluor #2 = Cy3",
    "Information|Image|Channel|Name #1 = Ch1-T1",
    "Information|Image|Channel|Name #2 = Ch2-T1",
    sep = "\n"
  )
  path <- local_tiff(
    planes,
    endian = "big",
    tags = c(
      list(list(270, 2, desc), list(282, 5, 10), list(283, 5, 10)),
      ij_private_tags(info = info, ranges = c(0, 65535, 0, 65535), luts = list(test_lut(c(0, 255, 0)), test_lut(c(255, 0, 255))))
    )
  )
  all <- read_images(path)
  expect_equal(nrow(all), 12)
  # rows are ordered by channel, then t, then z
  expect_equal(all$z, rep(1:3, 4))
  expect_equal(all$t, rep(rep(1:2, each = 3), 2))
  x <- all[all$z == 1 & all$t == 1, ]
  expect_equal(nrow(x), 2)
  expect_equal(x$channel, c("Alexa Fluor 488", "Cy3"))
  expect_equal(x$channel_name, c("Ch1-T1", "Ch2-T1"))
  expect_equal(x$color, c("#00FF00", "#FF00FF"))
  expect_equal(x$size_z, c(3L, 3L))
  expect_equal(x$size_t, c(2L, 2L))
  expect_equal(x$pixel_size, c(0.1, 0.1))
  expect_equal(x$z_step, c(0.5, 0.5))
  expect_equal(x$meta_source, c("imagej", "imagej"))
  expect_equal(x$pixel_size_source, c("imagej", "imagej"))

  for (c in 1:C) for (z in 1:Z) for (t in 1:T) {
    expect_identical(pixels(all, c, z, t), test_plane(c, z, t))
  }

  # z-projections of channel 2, time point 2
  stack <- all$img[all$channel_index == 2 & all$t == 2]
  expect_identical(img_pixels(max(stack))[[1]], test_plane(2, 3, 2))
  expect_identical(img_pixels(min(stack))[[1]], test_plane(2, 1, 2))
  expect_equal(img_pixels(mean(stack))[[1]], test_plane(2, 2, 2) * 1.0)
})

test_that("ImageJ description without unit gives no pixel size", {
  desc <- "ImageJ=1.54p\nimages=2\nslices=2\n"
  x <- read_images(local_tiff(list(test_plane(z = 1), test_plane(z = 2)), tags = list(list(270, 2, desc), list(282, 5, 1))))
  expect_equal(x$z, 1:2)
  expect_true(all(is.na(x$pixel_size)))
  expect_equal(unique(x$channel), "C1")
})

test_that("ImageJ metadata that don't match the pages are an error", {
  desc <- "ImageJ=1.54p\nimages=4\nchannels=2\nslices=2\nhyperstack=true\n"
  path <- local_tiff(list(test_plane(), test_plane()), tags = list(list(270, 2, desc)))
  expect_error(read_images(path), "describe 4 planes, but the file has 2 pages")

  one_page <- local_tiff(list(test_plane()), tags = list(list(270, 2, desc)), name = "big.tif")
  expect_error(read_images(one_page), "larger than 4 GB")
})

ome_test_xml <- function(dim_order = "XYZCT", size_c = 2, size_z = 2, tiff_data = NULL, file_name = NULL) {
  channels <- paste0(
    '<Channel ID="Channel:0:0" Name="Ch1" Fluor="AF488" Color="16711935" SamplesPerPixel="1"/>',
    '<Channel ID="Channel:0:1" Name="Ch2" Fluor="Cy3" Color="-16711681" SamplesPerPixel="1"/>'
  )
  paste0(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<OME xmlns="http://www.openmicroscopy.org/Schemas/OME/2016-06">',
    '<Image ID="Image:0" Name="test"><Pixels ID="Pixels:0" DimensionOrder="', dim_order, '" ',
    'Type="uint16" SizeX="5" SizeY="4" SizeC="', size_c, '" SizeZ="', size_z, '" SizeT="1" ',
    'PhysicalSizeX="100" PhysicalSizeXUnit="nm" PhysicalSizeY="100" PhysicalSizeYUnit="nm" ',
    'PhysicalSizeZ="0.3" PhysicalSizeZUnit="\u00b5m">',
    channels,
    paste(tiff_data, collapse = ""),
    "</Pixels></Image></OME>"
  )
}

test_that("OME-TIFF: DimensionOrder, TiffData, channels and units", {
  # XYZCT: z varies fastest, then c
  order <- expand.grid(z = 1:2, c = 1:2)
  planes <- lapply(seq_len(nrow(order)), function(k) test_plane(order$c[k], order$z[k]))
  tiff_data <- sprintf(
    '<TiffData FirstC="%d" FirstZ="%d" FirstT="0" IFD="%d" PlaneCount="1"/>',
    order$c - 1, order$z - 1, seq_len(nrow(order)) - 1
  )
  path <- local_tiff(planes, tags = list(list(270, 2, ome_test_xml(tiff_data = tiff_data))), name = "test.ome.tif")
  all <- read_images(path)
  expect_equal(nrow(all), 4)
  x <- all[all$z == 1, ]

  expect_equal(x$channel, c("AF488", "Cy3"))
  expect_equal(x$channel_name, c("Ch1", "Ch2"))
  expect_equal(x$color, c("#00FF00", "#FF00FF"))
  expect_equal(x$pixel_size, c(0.1, 0.1))
  expect_equal(x$z_step, c(0.3, 0.3))
  expect_equal(x$meta_source, c("ome-xml", "ome-xml"))
  for (c in 1:2) for (z in 1:2) {
    expect_identical(pixels(all, c, z), test_plane(c, z))
  }
})

test_that("OME-TIFF without TiffData uses DimensionOrder alone", {
  order <- expand.grid(c = 1:2, z = 1:2)
  planes <- lapply(seq_len(nrow(order)), function(k) test_plane(order$c[k], order$z[k]))
  path <- local_tiff(planes, tags = list(list(270, 2, ome_test_xml(dim_order = "XYCZT"))), name = "test.ome.tif")
  x <- read_images(path)
  for (c in 1:2) for (z in 1:2) {
    expect_identical(pixels(x, c, z), test_plane(c, z))
  }
})

test_that("OME-TIFF errors: multi-file and missing planes", {
  multi <- c(
    '<TiffData IFD="0" PlaneCount="2"><UUID FileName="a.ome.tif">urn:uuid:1</UUID></TiffData>',
    '<TiffData FirstC="1" IFD="0" PlaneCount="2"><UUID FileName="b.ome.tif">urn:uuid:2</UUID></TiffData>'
  )
  path <- local_tiff(lapply(1:2, function(i) test_plane()), tags = list(list(270, 2, ome_test_xml(tiff_data = multi))))
  expect_error(read_images(path), "Multi-file OME-TIFFs are not supported")

  path <- local_tiff(lapply(1:2, function(i) test_plane()), tags = list(list(270, 2, ome_test_xml())), name = "short.ome.tif")
  expect_error(read_images(path), "does not map all 4 planes to the 2 pages")
})

test_that("palette TIFF: raw values, colour from the ColorMap", {
  ramp <- 0:255 * 257
  cmap_red <- c(ramp, rep(0, 256), rep(0, 256))
  cmap_cyan <- c(rep(0, 256), ramp, ramp)
  planes <- list(test_plane(c = 0, z = 0, t = 1) %% 256L, matrix(as.integer(200:219), 4, 5))
  desc <- "ImageJ=\nhyperstack=true\nimages=2\nchannels=2\nslices=1\nframes=1"
  path <- local_tiff(
    planes,
    bits = 8,
    photometric = 3,
    tags = list(list(270, 2, desc)),
    page_tags = list(list(list(320, 3, cmap_red)), list(list(320, 3, cmap_cyan)))
  )
  x <- read_images(path)
  expect_equal(x$color, c("#FF0000", "#00FFFF"))
  expect_true(vctrs::vec_data(x$img)[[1]]$node$palette)
  expect_identical(pixels(x, 1), planes[[1]])
  expect_identical(pixels(x, 2), planes[[2]])
})

test_that("RGB TIFF: one channel per colour sample", {
  rgb <- array(0L, c(4, 5, 3))
  rgb[, , 1] <- 10L
  rgb[, , 2] <- matrix(0:19, 4, 5)
  rgb[, , 3] <- 250L
  x <- read_images(local_tiff(list(rgb), bits = 8))
  expect_equal(x$channel, c("red", "green", "blue"))
  expect_equal(x$color, c("#FF0000", "#00FF00", "#0000FF"))
  expect_identical(pixels(x, 2), rgb[, , 2])
  expect_identical(pixels(x, 3), rgb[, , 3])
})

test_that("read_images() combines files and expands directories", {
  dir <- withr::local_tempdir()
  write_test_tiff(file.path(dir, "b.tif"), list(test_plane()))
  write_test_tiff(file.path(dir, "a.tif"), list(test_plane(), test_plane(z = 2)))
  writeLines("notes", file.path(dir, "notes.txt"))

  x <- read_images(dir)
  expect_equal(basename(x$filepath), c("a.tif", "a.tif", "b.tif"))
  expect_equal(x$z, c(1L, 2L, 1L))

  x <- read_images(file.path(dir, c("b.tif", "a.tif")))
  expect_equal(basename(x$filepath), c("b.tif", "a.tif", "a.tif"))
})

test_that("read_images() validates paths", {
  dir <- withr::local_tempdir()
  writeLines("notes", file.path(dir, "notes.txt"))

  expect_error(read_images(1), "must be a character vector")
  expect_error(read_images(file.path(dir, "missing.tif")), "Can't find file")
  expect_error(read_images(file.path(dir, "notes.txt")), "Only TIFF files")
  expect_error(expect_warning(read_images(dir), "contains no TIFF files"), "No image files found")
})

test_that("read_images() refuses unsupported pixel types", {
  path <- local_tiff(list(test_plane()), tags = list(list(339, 3, 2)))
  expect_error(read_images(path), "16-bit signed integer")
})

test_that("to_micron() converts units and spellings", {
  expect_equal(to_micron(1, "\u00b5m"), 1)
  expect_equal(to_micron(1, "\u03bcm"), 1)
  expect_equal(to_micron(1, "micron"), 1)
  expect_equal(to_micron(1, "\\u00B5m"), 1)
  expect_equal(to_micron(1, "nm"), 1e-3)
  expect_equal(to_micron(1, "mm"), 1e3)
  expect_equal(to_micron(1, "\u00c5"), 1e-4)
  expect_true(is.na(to_micron(1, "inch")))
  expect_true(is.na(to_micron(1, "pixel")))
  expect_true(is.na(to_micron(1, NULL)))
  expect_true(is.na(to_micron(NA, "nm")))
})

test_that("ome_color() decodes signed RGBA integers", {
  expect_equal(ome_color("-16711681"), "#FF00FF")
  expect_equal(ome_color("16711935"), "#00FF00")
  expect_equal(ome_color("-1"), "#FFFFFF")
  expect_equal(ome_color(NA), NA_character_)
})

test_that("channel_labels() prefers unique fluors, then names", {
  expect_equal(channel_labels(c("a", "b"), c("DAPI", "GFP")), c("DAPI", "GFP"))
  expect_equal(channel_labels(c("a", "b"), c("GFP", "GFP")), c("a", "b"))
  expect_equal(channel_labels(c(NA, "b"), c(NA, "GFP")), c("C1", "C2"))
})
