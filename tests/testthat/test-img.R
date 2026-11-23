fake_img <- function(n = 3, size_x = 5L, size_y = 4L, pixel_size = 0.1) {
  new_img(lapply(seq_len(n), function(i) {
    img_source("fake.tif", page = i, size_x = size_x, size_y = size_y, pixel_size = pixel_size)
  }))
}

fake_images <- function() {
  tibble::tibble(
    filepath = "fake.tif",
    channel = rep(c("DAPI", "GFP"), each = 3),
    z = rep(1:3, 2),
    img = fake_img(6)
  )
}

test_that("image vectors print as pages and projections", {
  x <- fake_img(3)
  expect_true(is_img(x))
  expect_false(is_img(1:3))
  expect_equal(format(x), c("page 1", "page 2", "page 3"))
  expect_equal(format(max(x)), "max of 3")
  expect_equal(format(mean(c(max(x), min(x)))), "mean of 6")
  expect_equal(vctrs::vec_ptype_abbr(x), "img")
  expect_snapshot(fake_images())
})

test_that("projections keep the image geometry", {
  node <- vctrs::vec_data(max(fake_img(3)))[[1]]$node
  expect_equal(node$size_x, 5L)
  expect_equal(node$size_y, 4L)
  expect_equal(node$pixel_size, 0.1)
})

test_that("projections refuse incompatible or missing images", {
  expect_error(max(c(fake_img(1), fake_img(1, size_x = 9L))), "different sizes")
  expect_error(max(c(fake_img(1), fake_img(1, pixel_size = 0.2))), "different pixel sizes")
  expect_error(max(fake_img(0)), "zero images")
  expect_error(sum(fake_img(2)), "not supported for images")
})

test_that("images can't be sorted, compared arithmetically or mixed with other types", {
  x <- fake_img(2)
  expect_error(vctrs::vec_order(x), "can't be sorted")
  expect_error(x + 1)
  expect_error(vctrs::vec_c(x, 1))
})

# Robustness: the image column keeps its class through the operations users
# will apply to the image tibble. These rely on the vctrs extension interface.

test_that("img survives dplyr verbs", {
  skip_if_not_installed("dplyr")
  x <- fake_images()
  info <- tibble::tibble(channel = c("DAPI", "GFP"), protein = c("A", "B"))

  expect_true(is_img(dplyr::filter(x, z > 1)$img))
  expect_true(is_img(dplyr::arrange(x, dplyr::desc(z))$img))
  expect_true(is_img(dplyr::slice(x, 2:3)$img))
  expect_true(is_img(dplyr::mutate(x, img2 = img)$img2))
  expect_true(is_img(dplyr::rename(x, image = img)$image))
  expect_true(is_img(dplyr::relocate(x, img)$img))
  expect_true(is_img(dplyr::distinct(x, channel, .keep_all = TRUE)$img))
  expect_true(is_img(dplyr::left_join(x, info, by = "channel")$img))
  expect_true(is_img(dplyr::inner_join(info, x, by = "channel")$img))
  expect_true(is_img(dplyr::bind_rows(x, x)$img))
  expect_true(is_img(dplyr::bind_rows(split(x, x$channel))$img))

  proj <- dplyr::summarise(x, img = max(img), .by = channel)
  expect_true(is_img(proj$img))
  expect_equal(format(proj$img), c("max of 3", "max of 3"))

  grouped <- dplyr::summarise(dplyr::group_by(x, channel), img = mean(img))
  expect_equal(format(grouped$img), c("mean of 3", "mean of 3"))

  expect_error(dplyr::arrange(x, img), "can't be sorted")
})

test_that("img survives tidyr verbs", {
  skip_if_not_installed("tidyr")
  x <- fake_images()
  expect_true(is_img(tidyr::unnest(tidyr::nest(x, data = -channel), data)$img))
  wide <- tidyr::pivot_wider(x, names_from = z, values_from = img)
  expect_true(is_img(wide$`1`))
})

test_that("img survives base R operations", {
  x <- fake_images()
  expect_true(is_img(x[x$z == 1, ]$img))
  expect_true(is_img(rbind(x[1:2, ], x[3:4, ])$img))
  expect_true(is_img(rbind(as.data.frame(x[1:2, ]), as.data.frame(x[3:4, ]))$img))
  expect_true(is_img(as.data.frame(x)$img))
  expect_true(is_img(rev(x$img)))
  expect_true(is_img(head(x$img, 2)))
  expect_true(is_img(c(x$img[1], x$img[2])))

  i <- x$img
  i[2:3] <- i[5:6]
  expect_equal(format(i)[2:3], c("page 5", "page 6"))

  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(x, path)
  expect_identical(readRDS(path), x)
})
