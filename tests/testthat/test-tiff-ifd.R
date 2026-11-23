test_that("tiff_open() walks classic and BigTIFF files in both byte orders", {
  planes <- list(test_plane(z = 1), test_plane(z = 2), test_plane(z = 3))
  for (bigtiff in c(FALSE, TRUE)) {
    for (endian in c("little", "big")) {
      path <- local_tiff(planes, endian = endian, bigtiff = bigtiff)
      tf <- tiff_open(path)
      expect_equal(tf$bigtiff, bigtiff)
      expect_equal(tf$endian, endian)
      expect_length(tf$ifds, 3)
      info <- tiff_page_info(tf, 2)
      expect_equal(info$width, 5)
      expect_equal(info$height, 4)
      expect_equal(info$bits, 16)
    }
  }
})

test_that("tiff_tag() decodes the common tag types", {
  path <- local_tiff(
    list(test_plane()),
    tags = list(
      list(270, 2, "hello"),
      list(282, 5, 14.1363),
      list(50000, 12, c(1.5, -2)),
      list(50001, 3, c(1, 2, 65535))
    )
  )
  tf <- tiff_open(path)
  expect_equal(bytes_to_utf8(tiff_tag_bytes(tf, 1, 270)), "hello")
  expect_equal(tiff_tag(tf, 1, 282), 14.1363)
  expect_equal(tiff_tag(tf, 1, 50000), c(1.5, -2))
  expect_equal(tiff_tag(tf, 1, 50001), c(1, 2, 65535))
  expect_null(tiff_tag(tf, 1, 12345))
})

test_that("tiff_open() rejects files that are not TIFFs", {
  path <- withr::local_tempfile(fileext = ".tif")
  writeLines("not a tiff", path)
  expect_error(tiff_open(path), "is not a TIFF file")
})
