#' Start a montage
#'
#' `tidymontage()` turns a tibble of images into a montage. Like `tidyplot()`
#' in tidyplots, it takes the mapping and the size; `add_*()` and `adjust_*()`
#' verbs then add merges, crops, zooms, scale bars and more. Nothing is read
#' from disk until the montage is printed or saved.
#'
#' The images tibble decides *which* images are shown: select planes with
#' `filter()` and project z-stacks with `summarise(img = max(img))` before
#' calling `tidymontage()`. Everything visual is decided by the montage.
#'
#' Columns mapped to `x` and `y` (such as `condition`) arrange blocks of
#' panels. Within each block, the layout arranges channels and views (see
#' [layout_grid()]); in the grid, map `channel` or `view` to `x` or `y` to
#' place them yourself. Merges and zooms added later become levels of
#' `channel` and `view`. Each panel must show exactly one image.
#'
#' @param images A data frame of images, usually from [read_images()]. Must
#'   contain the columns `filepath`, `channel` and `img`.
#' @param x,y Columns mapped to the columns (`x`) and rows (`y`) of the montage:
#'   a bare name such as `condition`, or several with `c()` (the first one
#'   varies slowest). In the grid layout, `channel` and `view` can be mapped
#'   too.
#' @param ... Choose and order the levels of panel dimensions, for example
#'   `channel = c("GFP", "DAPI")` or `condition = "ctrl"`.
#' @param layout `"grid"` (the default) or `"hero"`, or a layout created with
#'   [layout_grid()] or [layout_hero()].
#' @param gap Gap between panels in mm.
#' @param width,height,units Size of the box the panel grid fits into, see
#'   [adjust_size()]. Default: 90 x 90 mm.
#'
#' @returns A `tidymontage` object. Printing it draws the montage.
#'
#' @examples
#' \dontrun{
#' read_images(c("ctrl.ome.tif", "ko.ome.tif")) |>
#'   dplyr::mutate(condition = ifelse(grepl("ctrl", filepath), "ctrl", "ko")) |>
#'   tidymontage(x = condition)
#' }
#'
#' @export
tidymontage <- function(images, x = NULL, y = NULL, ..., layout = "grid", gap = 1,
                        width = 90, height = 90, units = c("mm", "cm", "in")) {
  check_images(images)
  images <- tibble::as_tibble(images)
  x <- dims_from_quo(rlang::enquo(x), images, arg = "x")
  y <- dims_from_quo(rlang::enquo(y), images, arg = "y")
  check_xy(x, y)
  setup <- list(
    x = x,
    y = y,
    levels = check_levels(rlang::list2(...), images),
    layout = as_layout(layout),
    gap = check_gap(gap),
    size = size_spec(width, height, rlang::arg_match(units))
  )
  new_tidymontage(images = images, setup = setup)
}

new_tidymontage <- function(images, setup = default_setup(), steps = list()) {
  structure(list(images = images, setup = setup, steps = steps), class = "tidymontage")
}

default_setup <- function() {
  list(
    x = character(), y = character(), levels = list(), layout = layout_grid(), gap = 1,
    size = size_spec(90, 90, "mm")
  )
}

#' Test if an object is a tidymontage
#'
#' @param x An object.
#' @returns `TRUE` if `x` is a `tidymontage` object, otherwise `FALSE`.
#' @export
is_tidymontage <- function(x) {
  inherits(x, "tidymontage")
}

# Input checks -----------------------------------------------------------------

required_image_cols <- c("filepath", "channel", "img")

check_images <- function(images, call = rlang::caller_env()) {
  if (!is.data.frame(images)) {
    cli::cli_abort(
      "{.arg images} must be a data frame, not {.obj_type_friendly {images}}.",
      call = call
    )
  }
  missing <- setdiff(required_image_cols, names(images))
  if (length(missing) > 0) {
    cli::cli_abort(
      c(
        "{.arg images} must contain the column{?s} {.field {required_image_cols}}.",
        "x" = "Missing: {.field {missing}}."
      ),
      call = call
    )
  }
  if (!is_img(images$img)) {
    cli::cli_abort(
      c(
        "Column {.field img} must be an image vector, not {.obj_type_friendly {images$img}}.",
        "i" = "Create images with {.fn read_images}."
      ),
      call = call
    )
  }
  if (!is.character(images$filepath)) {
    cli::cli_abort(
      "Column {.field filepath} must be a character vector, not {.obj_type_friendly {images$filepath}}.",
      call = call
    )
  }
  if ("view" %in% names(images)) {
    cli::cli_abort(
      "{.arg images} can't have a column named {.field view}: it is reserved for the montage views.",
      call = call
    )
  }
  invisible(images)
}

check_tidymontage <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (!is_tidymontage(x)) {
    cli::cli_abort(
      "{.arg {arg}} must be a {.cls tidymontage} object, not {.obj_type_friendly {x}}.",
      call = call
    )
  }
  invisible(x)
}
