#' Crop the images
#'
#' `add_crop()` shows a region of each image instead of the full image. The
#' size of the region is the same for all images, so all panels share the same
#' magnification; only its position can differ between images.
#'
#' Positions are given as the **center** of the region, either one position
#' for all images or a data frame with one position per image or group. By
#' default, positions are relative to the full image (`0` = left or top edge,
#' `1` = right or bottom edge); with `center_units = "px"` they are pixel
#' coordinates of the full image, counted from 0 as in ImageJ / Fiji.
#'
#' Display ranges are always computed from the full images, so moving a crop
#' doesn't change brightness.
#'
#' A montage has one crop: calling `add_crop()` again replaces the earlier
#' crop. Use [add_zoom()] for further regions.
#'
#' With `angle`, the region is rotated, for structures that run at an angle,
#' such as a neurite. The angle is the one Fiji reports for a line drawn along
#' the structure (*Analyze > Measure*): in degrees, counterclockwise. The
#' region's width runs along that line, and the panel shows it upright, so the
#' structure lies horizontal. Rotated regions are sampled with bilinear
#' interpolation, at the original pixel size. Unlike upright regions, they are
#' not moved inside the image: all their corners must lie within it.
#'
#' @param montage A [tidymontage()] object.
#' @param width,height Size of the region. In micrometres by default, which
#'   keeps the magnification equal even if images have different pixel sizes.
#' @param center Position of the region's center: a numeric vector `c(x, y)`
#'   used for all images, or a data frame with columns `x`, `y` and one or more
#'   columns of the images tibble to match on, e.g. `condition` or `filepath`.
#'   The data frame can also have an `angle` column, for a different angle per
#'   image.
#' @param units Units of `width` and `height`: `"um"` (micrometres, needs a
#'   known pixel size) or `"px"` (pixels).
#' @param center_units Units of `center`: `"rel"` (relative, 0-1) or `"px"`.
#' @param name Name of the view in the layout.
#' @param angle Rotation of the region in degrees, counterclockwise, as Fiji
#'   measures the angle of a line. `NULL` (the default) means no rotation,
#'   unless `center` has an `angle` column.
#'
#' @returns The montage with the crop step added.
#' @examples
#' \dontrun{
#' centers <- tibble::tibble(condition = c("ctrl", "ko"), x = c(0.4, 0.6), y = c(0.5, 0.3))
#' montage |> add_crop(width = 40, center = centers)
#'
#' # rotated, with an angle per image
#' centers$angle <- c(30, -15)
#' montage |> add_crop(width = 40, center = centers)
#' }
#' @export
add_crop <- function(montage, width, height = width, center = c(0.5, 0.5),
                        units = c("um", "px"), center_units = c("rel", "px"), name = "crop",
                        angle = NULL) {
  check_tidymontage(montage)
  view <- new_view_spec(
    width, height, center, rlang::arg_match(units), rlang::arg_match(center_units), name, montage,
    angle = angle, replaces = "add_crop"
  )
  add_step(montage, new_step("add_crop", view))
}

#' Add a blow-up of a region
#'
#' `add_zoom()` adds a new view to the montage: an enlarged region of each
#' image, shown as panels of their own. Map `view` to `x` or `y` in the layout
#' to show them next to the main panels, or choose them with
#' `layout_grid(view = "zoom")`. A box marks the region on the main panels.
#'
#' As for [add_crop()], the size is the same for all images, so all
#' blow-ups share one magnification, and positions are centers relative to the
#' full image by default.
#'
#' Call `add_zoom()` again for more zooms. With two or more, they are numbered
#' in the order they were added: the number is shown in the top-left corner of
#' each box and of each panel of that zoom, and the views are named
#' `"zoom 1"`, `"zoom 2"`, ... unless `name` is given.
#'
#' @inheritParams add_crop
#' @param name Name of the view in the layout. By default `"zoom"`, or
#'   `"zoom 1"`, `"zoom 2"`, ... if the montage has several zooms.
#' @param box Where to draw the box that marks the region on the main panels:
#'   on `"all"` panels, only on `"merge"` panels, or `"none"`.
#' @param angle Rotation of the region in degrees, counterclockwise, see
#'   [add_crop()]. `NULL` (the default) takes the angle of the crop, so the
#'   zoom box sits square in a rotated crop; `0` keeps the zoom upright.
#' @param label Label shown in the box and in the zoom panels. By default the
#'   number of the zoom if the montage has several, otherwise none. A string
#'   sets your own label; `NA` shows none.
#'
#' @returns The montage with the zoom step added.
#' @examples
#' \dontrun{
#' montage |>
#'   add_crop(width = 40) |>
#'   add_zoom(width = 8, center = c(0.45, 0.6)) |>
#'   layout_grid(x = channel, y = view)
#'
#' # two numbered zooms
#' montage |>
#'   add_zoom(width = 8, center = c(0.45, 0.6)) |>
#'   add_zoom(width = 8, center = c(0.7, 0.3))
#' }
#' @export
add_zoom <- function(montage, width, height = width, center = c(0.5, 0.5),
                     units = c("um", "px"), center_units = c("rel", "px"), name = NULL,
                     box = c("all", "merge", "none"), label = NULL, angle = NULL) {
  check_tidymontage(montage)
  view <- new_view_spec(
    width, height, center, rlang::arg_match(units), rlang::arg_match(center_units), name, montage,
    angle = angle
  )
  view$box <- rlang::arg_match(box)
  if (!is.null(label) && !(length(label) == 1 && (is.na(label) || is.character(label)))) {
    cli::cli_abort("{.arg label} must be a single string or {.code NA}.")
  }
  view$label <- if (is.null(label)) NULL else as.character(label)
  add_step(montage, new_step("add_zoom", view))
}

new_view_spec <- function(width, height, center, units, center_units, name, montage,
                          angle = NULL, replaces = NULL, call = rlang::caller_env()) {
  for (arg in c("width", "height")) {
    v <- get(arg)
    if (!is.numeric(v) || length(v) != 1 || is.na(v) || v <= 0) {
      cli::cli_abort("{.arg {arg}} must be a single positive number.", call = call)
    }
  }
  # zooms without a name are named when the montage is built
  if (!is.null(name)) {
    if (!rlang::is_string(name) || !nzchar(name)) {
      cli::cli_abort("{.arg name} must be a single non-empty string.", call = call)
    }
    # A new crop replaces an earlier one, so only other views can clash.
    view_steps <- setdiff(c("add_crop", "add_zoom"), replaces)
    used <- unlist(lapply(montage$steps, function(s) if (s$type %in% view_steps) s$params$name))
    if (name %in% c(used, "full")) {
      cli::cli_abort("The view name {.val {name}} is already used.", call = call)
    }
  }
  check_center(center, center_units, montage$images, call, angle = TRUE)
  if (!is.null(angle)) {
    if (!is.numeric(angle) || length(angle) != 1 || !is.finite(angle)) {
      cli::cli_abort("{.arg angle} must be a single number (degrees).", call = call)
    }
    if (is.data.frame(center) && "angle" %in% names(center)) {
      cli::cli_abort("Give the angle either as {.arg angle} or as a column of {.arg center}, not both.", call = call)
    }
  }
  list(
    name = name, width = width, height = height, units = units,
    center = center, center_units = center_units, angle = angle
  )
}

# Positions: c(x, y), or a data frame with columns x, y and columns of the
# images tibble to match on. Crops and zooms need one position per image;
# arrows (`several = TRUE`) can have any number.
check_center <- function(center, center_units, images, call, arg = "center", several = FALSE,
                         angle = FALSE) {
  if (is.numeric(center)) {
    if (length(center) != 2 || anyNA(center)) {
      cli::cli_abort("{.arg {arg}} must be {.code c(x, y)} or a data frame.", call = call)
    }
    if (center_units == "rel" && any(center < 0 | center > 1)) {
      cli::cli_abort("Relative {.arg {arg}} values must be between 0 and 1.", call = call)
    }
    return(invisible())
  }
  if (!is.data.frame(center)) {
    cli::cli_abort("{.arg {arg}} must be {.code c(x, y)} or a data frame, not {.obj_type_friendly {center}}.", call = call)
  }
  if (!all(c("x", "y") %in% names(center)) || !is.numeric(center$x) || !is.numeric(center$y)) {
    cli::cli_abort("A {.arg {arg}} data frame needs numeric columns {.field x} and {.field y}.", call = call)
  }
  keys <- setdiff(names(center), c("x", "y", if (angle) "angle"))
  if (angle && "angle" %in% names(center) && !is.numeric(center$angle)) {
    cli::cli_abort("The {.field angle} column of {.arg {arg}} must be numeric (degrees).", call = call)
  }
  unknown <- setdiff(keys, names(images))
  if (length(unknown) > 0) {
    cli::cli_abort(
      "{.arg {arg}} has column{?s} {.field {unknown}} that {?is/are} not in the images tibble.",
      call = call
    )
  }
  if (!several && length(keys) == 0 && nrow(center) != 1) {
    cli::cli_abort("A {.arg {arg}} data frame with several rows needs columns to match images on, e.g. {.field condition}.", call = call)
  }
  if (several && (anyNA(center$x) || anyNA(center$y))) {
    cli::cli_abort("{.arg {arg}} must not contain missing positions.", call = call)
  }
  if (center_units == "rel" && any(c(center$x, center$y) < 0 | c(center$x, center$y) > 1, na.rm = TRUE)) {
    cli::cli_abort("Relative {.arg {arg}} values must be between 0 and 1.", call = call)
  }
  invisible()
}

format_view_step <- function(x, verb) {
  p <- x$params
  center <- if (is.numeric(p$center)) {
    paste0("c(", paste(p$center, collapse = ", "), ")")
  } else {
    keys <- setdiff(names(p$center), c("x", "y", "angle"))
    paste0(
      "<", nrow(p$center), " centers", if ("angle" %in% names(p$center)) " and angles",
      " by ", paste(keys, collapse = ", "), ">"
    )
  }
  args <- c(
    paste0("width = ", p$width),
    if (p$height != p$width) paste0("height = ", p$height),
    paste0("center = ", center),
    if (p$units != "um") paste0("units = \"", p$units, "\""),
    if (p$center_units != "rel") paste0("center_units = \"", p$center_units, "\""),
    if (!is.null(p$name)) paste0("name = \"", p$name, "\""),
    if (!is.null(p$angle)) paste0("angle = ", p$angle),
    if (!is.null(p$box) && p$box != "all") paste0("box = \"", p$box, "\""),
    if (!is.null(p$label)) paste0("label = ", if (is.na(p$label)) "NA" else paste0("\"", p$label, "\""))
  )
  paste0(verb, "(", paste(args, collapse = ", "), ")")
}

#' @export
format.tidymontage_step_add_crop <- function(x, ...) format_view_step(x, "add_crop")

#' @export
format.tidymontage_step_add_zoom <- function(x, ...) format_view_step(x, "add_zoom")
