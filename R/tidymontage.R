#' Start a montage
#'
#' `tidymontage()` turns a data frame of images into a montage recipe. Nothing
#' is read from disk at this point: the `add_*()` and `adjust_*()` verbs append
#' steps to the recipe, and pixels are only read when the montage is rendered.
#'
#' @param images A data frame of images, usually from [read_images()]. Must
#'   contain the columns `filepath`, `channel` and `img`. Any additional
#'   columns, such as `condition`, can be used in `x` and `y`.
#' @param x,y <[`data-masking`][rlang::args_data_masking]> Variables that are
#'   mapped to the columns (`x`) and rows (`y`) of the montage, for example
#'   `condition` or `genotype`. Use `NULL` (the default) for no mapping.
#' @param layout A layout specification. Layouts are not implemented yet, so
#'   this must currently be `NULL`.
#'
#' @returns A `tidymontage` object.
#'
#' @examples
#' \dontrun{
#' read_images(c("ctrl.ome.tif", "ko.ome.tif")) |>
#'   dplyr::mutate(condition = ifelse(grepl("ctrl", filepath), "ctrl", "ko")) |>
#'   tidymontage(x = condition)
#' }
#'
#' @export
tidymontage <- function(images, x = NULL, y = NULL, layout = NULL) {
  check_images(images)
  images <- tibble::as_tibble(images)
  mapping <- list(x = rlang::enquo(x), y = rlang::enquo(y))
  check_mapping(mapping, images)
  check_layout(layout)
  new_tidymontage(images = images, mapping = mapping, layout = layout)
}

new_tidymontage <- function(images, mapping, layout = NULL, steps = list()) {
  structure(
    list(images = images, mapping = mapping, layout = layout, steps = steps),
    class = "tidymontage"
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
  invisible(images)
}

check_mapping <- function(mapping, images, call = rlang::caller_env()) {
  for (aes in names(mapping)) {
    quo <- mapping[[aes]]
    if (rlang::quo_is_null(quo)) {
      next
    }
    value <- tryCatch(
      rlang::eval_tidy(quo, data = images),
      error = function(cnd) {
        cli::cli_abort(
          "Can't map {.arg {aes}} to {.code {rlang::as_label(quo)}}.",
          parent = cnd,
          call = call
        )
      }
    )
    if (!length(value) %in% c(1L, nrow(images))) {
      cli::cli_abort(
        c(
          "{.arg {aes}} must have length 1 or {nrow(images)} (the number of images).",
          "x" = "{.code {rlang::as_label(quo)}} has length {length(value)}."
        ),
        call = call
      )
    }
  }
  invisible(mapping)
}

check_layout <- function(layout, call = rlang::caller_env()) {
  if (!is.null(layout)) {
    cli::cli_abort(
      "Layouts are not implemented yet, {.arg layout} must be {.code NULL}.",
      call = call
    )
  }
  invisible(layout)
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
