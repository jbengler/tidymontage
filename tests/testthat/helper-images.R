example_images <- function() {
  tibble::tibble(
    filepath = rep(c("ctrl.tif", "ko.tif"), each = 2),
    channel = rep(c("DAPI", "GFP"), times = 2),
    condition = rep(c("ctrl", "ko"), each = 2),
    img = new_img(lapply(1:4, function(i) img_source("fake.tif", page = i, size_x = 5L, size_y = 4L)))
  )
}
