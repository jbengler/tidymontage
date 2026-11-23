#' Add scale bars
#'
#' Adds a scale bar to the panels of a montage. Panels of one view share the
#' same magnification (see [adjust_crop()]), so by default one bar per view is
#' drawn, in the bottom-right panel of that view.
#'
#' Scale bars need a known pixel size. If the images of a view have different
#' magnifications, for example uncropped images with different pixel sizes,
#' every panel of that view gets its own bar.
#'
#' @param montage A [tidymontage()] object.
#' @param length Length of the bar in micrometres: a single number for all
#'   views, a named vector per view (e.g. `c(crop = 10, zoom = 2)`), or `NULL`
#'   to choose a round length of about a fifth of the panel width.
#' @param where Which panels get a bar: `"last"` (one per view), `"all"`, or
#'   `"merge"` (all merge panels).
#' @param position Corner of the panel.
#' @param color Colour of the bar and its label.
#' @param outline Colour of a thin border around the bar and a halo around the
#'   label, which keeps them visible on bright image content. `NA` for none.
#' @param label Show the length above the bar?
#' @param size Text size in points.
#' @param thickness Thickness of the bar in mm.
#' @param inset Distance from the panel edges in mm.
#'
#' @returns The montage with the scale bar step added.
#' @examples
#' \dontrun{
#' montage |> add_scale_bar(10)
#' montage |> add_scale_bar(c(crop = 10, zoom = 2), where = "all")
#' }
#' @export
add_scale_bar <- function(montage, length = NULL, where = c("last", "all", "merge"),
                          position = c("bottomright", "bottomleft", "topright", "topleft"),
                          color = "white", outline = "black", label = TRUE, size = 7,
                          thickness = 0.6, inset = 1.5) {
  check_tidymontage(montage)
  if (!is.null(length) && (!is.numeric(length) || anyNA(length) || any(length <= 0))) {
    cli::cli_abort("{.arg length} must be positive numbers (micrometres) or {.code NULL}.")
  }
  if (!is.null(length) && base::length(length) > 1 && !rlang::is_named(length)) {
    cli::cli_abort("Several lengths in {.arg length} must be named by view, e.g. {.code c(crop = 10, zoom = 2)}.")
  }
  check_color(color, "color")
  if (!(base::length(outline) == 1 && is.na(outline))) check_color(outline, "outline")
  check_number(size, "size")
  check_number(thickness, "thickness")
  check_number(inset, "inset", zero = TRUE)
  add_step(montage, new_step("add_scale_bar", list(
    length = length, where = rlang::arg_match(where), position = rlang::arg_match(position),
    color = color, outline = outline, label = isTRUE(label), size = size, thickness = thickness, inset = inset
  )))
}

#' Adjust the row and column headers
#'
#' Headers name the levels mapped to `x` (above the columns) and `y` (left of
#' the rows). When several dimensions share an axis, headers are nested: the
#' outer level spans the columns or rows it contains.
#'
#' @param montage A [tidymontage()] object.
#' @param x,y Show the column (`x`) and row (`y`) headers?
#' @param size Text size in points.
#' @param color Text colour.
#'
#' @returns The montage with the header step added.
#' @examples
#' \dontrun{
#' montage |> adjust_headers(y = FALSE, size = 8)
#' }
#' @export
adjust_headers <- function(montage, x = TRUE, y = TRUE, size = 7, color = "black") {
  check_tidymontage(montage)
  check_number(size, "size")
  check_color(color, "color")
  add_step(montage, new_step("adjust_headers", list(x = isTRUE(x), y = isTRUE(y), size = size, color = color)))
}

check_color <- function(x, arg, call = rlang::caller_env()) {
  ok <- rlang::is_string(x) && !inherits(try(grDevices::col2rgb(x), silent = TRUE), "try-error")
  if (!ok) {
    cli::cli_abort("{.arg {arg}} must be a single valid colour.", call = call)
  }
}

check_number <- function(x, arg, zero = FALSE, call = rlang::caller_env()) {
  ok <- is.numeric(x) && length(x) == 1 && !is.na(x) && (x > 0 || (zero && x == 0))
  if (!ok) {
    cli::cli_abort("{.arg {arg}} must be a single {if (zero) 'non-negative' else 'positive'} number.", call = call)
  }
}

# Lengths: 1, 2 or 5 times a power of ten, about a fifth of the width.
nice_length <- function(width_um) {
  target <- width_um / 5
  p <- 10^floor(log10(target))
  steps <- c(1, 2, 5, 10) * p
  max(steps[steps <= target])
}

# Printing: only arguments that differ from the defaults.
format_args <- function(params, defaults) {
  keep <- vapply(names(params), function(nm) {
    !nm %in% names(defaults) || !identical(params[[nm]], defaults[[nm]])
  }, logical(1))
  vapply(names(params)[keep], function(nm) {
    v <- params[[nm]]
    val <- if (is.null(v)) "NULL" else if (is.character(v) && length(v) == 1) paste0("\"", v, "\"") else {
      paste(deparse(v), collapse = "")
    }
    paste0(nm, " = ", val)
  }, character(1))
}

#' @export
format.tidymontage_step_add_scale_bar <- function(x, ...) {
  defaults <- list(
    length = NULL, where = "last", position = "bottomright", color = "white", outline = "black", label = TRUE,
    size = 7, thickness = 0.6, inset = 1.5
  )
  p <- x$params
  args <- c(
    if (!is.null(p$length)) paste(deparse(p$length), collapse = ""),
    format_args(p[setdiff(names(p), "length")], defaults)
  )
  paste0("add_scale_bar(", paste(args, collapse = ", "), ")")
}

#' @export
format.tidymontage_step_adjust_headers <- function(x, ...) {
  defaults <- list(x = TRUE, y = TRUE, size = 7, color = "black")
  args <- format_args(x$params, defaults)
  paste0("adjust_headers(", paste(args, collapse = ", "), ")")
}
